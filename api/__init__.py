import os
import time
import logging
import tiktoken
import re
import json
import asyncio
from azure.eventhub import EventData
from azure.eventhub.aio import EventHubProducerClient


EVENT_HUB_CONNECTION_STR = os.environ.get("EVENT_HUB_CONNECTION_STR")
EVENT_HUB_NAME = os.environ.get("EVENT_HUB_NAME")

producer = EventHubProducerClient.from_connection_string(
        conn_str=EVENT_HUB_CONNECTION_STR, eventhub_name=EVENT_HUB_NAME,
    )

logging.basicConfig(filename="/var/log/loghelper_openai.log",
    filemode='a',
    format='%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s',
    datefmt='%H:%M:%S',
    level=logging.DEBUG)

logger = logging.getLogger(__name__)

def num_tokens_from_string(string: str, encoding_name: str) -> int:
    """Returns the number of tokens in a text string."""
    encoding = tiktoken.get_encoding(encoding_name)
    num_tokens = len(encoding.encode(string))
    return num_tokens

headers_regex = re.compile(r"(\S+): (\S+)")

def parse_headers(headers: str) -> dict:
    """Parses a string of HTTP headers into a dictionary."""
    headers_dict = {}
    matches = headers_regex.findall(headers)
    for m in matches:
            headers_dict[m[0]] = m[1]
    return headers_dict

parse_resp_body_regex = re.compile(r"data: (.+)")

def parse_resp_body(resp_body: str) -> dict:
    """Parses a string of HTTP response body into a dictionary."""
    resp_body_dict = {
        "data": []
    }
    matches = parse_resp_body_regex.findall(resp_body.encode("utf-8").decode('unicode-escape'))
    #logger.info(matches)
    for m in matches:
        try:
            j = json.loads(m.replace(':nul l,', ':null,').replace(':nu ll,', ':null,').replace(':n ull,', ':null,'))
            clean_j = cleanup_json(j)
            resp_body_dict["data"].append(clean_j)
        except Exception as e:
            logger.info(f"NOT JSON: {m}")
    if len(matches) == 0:
        try:
            #logging.info(f"Strip: {resp_body.strip()}")
            #logging.info(f"strip encode/decode: {resp_body.strip().encode('utf-8').decode('unicode-escape')}")
            #logging.info(f"encode/decode strip: {resp_body.encode('utf-8').decode('unicode-escape').strip()}")
            logging.info(f"encode/decode strip splitlines: {resp_body.encode('utf-8').decode('unicode-escape').strip().splitlines()}")
            j = json.loads(resp_body.encode('utf-8').decode('unicode-escape').strip().splitlines()[0])
            logging.info("Hey it is json!")
            logging.info(j)
            clean_j = cleanup_json(j)
            resp_body_dict["data"].append(clean_j)
        except Exception as e:
            logger.info(f"NOT JSON: {resp_body}")
    logging.info(f"PARSE RESP BODY! {resp_body_dict}")

    return resp_body_dict

def cleanup_json(d: dict) -> dict:
    clean_dict = {}
    for k, v in d.items():
        new_key = k.replace(" ", "")
        if isinstance(v, dict):
            new_v = cleanup_json(v)
            clean_dict[new_key] = new_v
        elif isinstance(v, list):
            new_v = []
            for i in v:
                if isinstance(i, dict):
                    new_v.append(cleanup_json(i))
                else:
                    new_v.append(i)
            clean_dict[new_key] = new_v
        elif isinstance(v, str) or isinstance(v, bytes):
            clean_dict[new_key] = f"{v}"
        else: 
            clean_dict[new_key] = v
    return clean_dict
       
# https://medium.com/@aliasav/how-follow-a-file-in-python-tail-f-in-python-bca026a901cf
def follow(f):
    '''generator function that yields new lines in a file
    '''
    # seek the end of the file
    f.seek(0, os.SEEK_END)
    # start infinite loop
    while True:
        # read last line of file
        line = f.readline()
        # sleep if file hasn't been updated
        if not line:
            time.sleep(0.1)
            continue

        yield line   

async def send_to_event_hub(event: EventData):
    logging.info("!!! send to event hub start !!!")
    event_batch = await producer.create_batch()
    event_batch.add(event)
    await producer.send_batch(event_batch)
    logging.info("!!! send to event hub complete !!!")

def main():
    logfile = open("/var/log/nginx_access.log","r")
    loglines = follow(logfile)
    # iterate over the generator
    for line in loglines:
        try:
            line_split = line.split('" ||| "')
            logger.info("---")
            # req headers
            req_headers = parse_headers(line_split[1])
            logger.info(req_headers)
            # resp headers
            resp_headers = parse_headers(line_split[2])
            logger.info(resp_headers)
            logger.info("-")
            resp_body = parse_resp_body(line_split[3])
            resp_body_arr = []
            logger.info(len(resp_body["data"]))
            num_tokens = 0
            for d in resp_body["data"]:
                try:
                    if "choices" in d and len(d["choices"]) > 0 and "delta" in d["choices"][0] and "content" in d["choices"][0]["delta"]:
                        resp_body_arr.append(d["choices"][0]["delta"]["content"])
                    if "choices" in d and len(d["choices"]) > 0 and "message" in d["choices"][0] and "content" in d["choices"][0]["message"]:
                        resp_body_arr.append(d["choices"][0]["message"]["content"])
                        if "usage" in d and "completion_tokens" in d["usage"]:
                            num_tokens = d['usage']['completion_tokens']
                except Exception as e:
                    logger.info(f"Cannot logger.info content: {d}")
                    logger.info(f"Because of: {e}")
            resp_body_content = "".join(resp_body_arr)
            logger.info(resp_body_content)
            num_tokens = num_tokens_from_string(resp_body_content, 'cl100k_base') if num_tokens == 0 else num_tokens
            logger.info(f"Number of Tokens: {num_tokens}")
            if num_tokens > 0:
                event = EventData(json.dumps({
                    "Type": "openai-log-helper-proxy",
                    "req_headers": req_headers,
                    "resp_headers": resp_headers,
                    "body_content": resp_body_content,
                    "num_tokens": num_tokens,
                }).encode('utf-8'))
                logger.info("---")
                asyncio.run(send_to_event_hub(event))
                logger.info(f"Event: {event}")
            logger.info("-------------------------")
        except Exception as e:
            logging.error(f"Error in tailing: {e}")

if __name__ == "__main__":
    logger.info("start main...")
    #asyncio.run(main())
    main()
    logger.info("stop main...")