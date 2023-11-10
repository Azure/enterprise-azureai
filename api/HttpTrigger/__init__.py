# FILEPATH: /c:/GitHub/ais-apim-openai/api/HttpTrigger/__init__.py
import logging
import requests
import json
import azure.functions as func
import os

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    message = req.params.get('message')
    if not message:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            message = req_body.get('message')

    if message:
        # OpenAI API URL
        url = os.getenv('OpenAiUri')

        # Request headers
        headers = {
            "Content-Type": "application/json",
            "api-key": os.getenv('OpenAiKey')
        }

        # Data to be sent to OpenAI API
        data = {
            "prompt": message,
            "max_tokens": 60
        }

        # Making a POST request to OpenAI API
        response = requests.post(url, headers=headers, data=json.dumps(data))

        # If the request was successful, return the response from OpenAI API
        if response.status_code == 200:
            response_json = response.json()
            tokens_used = len(response_json.get('choices')[0].get('text'))
            logging.info(f'Tokens used: {tokens_used}')
            return func.HttpResponse(response_json)
        else:
            return func.HttpResponse(
                "Error in processing the request with OpenAI API.",
                status_code=500
            )
    else:
        return func.HttpResponse(
            "This HTTP triggered function executed successfully. Pass a message in the query string or in the request body for a personalized response.",
            status_code=200
        )