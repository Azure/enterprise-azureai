import Typography from "@/components/typography";
import { Card } from "@/components/ui/card";
import { FC } from "react";
import { useChatContext } from "../chat-context";
import { ChatFileUI } from "../chat-file/chat-file-ui";
import { ChatStyleSelector } from "./chat-style-selector";
import { ChatTypeSelector } from "./chat-type-selector";
import { ChatDeploymentSelector } from "./chat-deployment-selector";
import { ChatDepartmentSelector } from "./chat-department-selector";
import { DepartmentConfig, DeploymentConfig } from "../../chat-services/models";


interface Prop {
  deployments: DeploymentConfig[];
  departments: DepartmentConfig[];
}

export const ChatMessageEmptyState: FC<Prop> = (props) => {
  const { fileState } = useChatContext();

  const { showFileUpload } = fileState;

  return (
    <div className="grid grid-cols-5 w-full items-center container mx-auto max-w-3xl justify-center h-full gap-9">
      <div className="col-span-2 gap-5 flex flex-col flex-1">
        <img src="/ai-icon.png" className="w-36" />
        <p className="">
          Start by just typing your message in the box below. You can also
          personalise the chat by making changes to the settings on the right.
        </p>
      </div>
      <Card className="col-span-3 flex flex-col gap-3 p-5 ">
        <Typography variant="h4" className="text-primary">
          Personalise
        </Typography>

        <div className="flex flex-col gap-2">
          <p className="text-sm text-muted-foreground">
            Choose a conversation style
          </p>
          <ChatStyleSelector disable={false} />
        </div>
        {/* for now we are not supporting files}
        {/* <div className="flex flex-col gap-2">
          <p className="text-sm text-muted-foreground">
            How would you like to chat?
          </p>
          <ChatTypeSelector disable={true} />
        </div>
        {showFileUpload === "data" && <ChatFileUI />} */}
        <div className="flex flex-col gap-2">
          <p className="text-sm text-muted-foreground">
            Which deployment model would you like to use?
          </p>
          <ChatDeploymentSelector disable={false} deployments={props.deployments}/>
        </div>
        <div className="flex flex-col gap-2">
          <p className="text-sm text-muted-foreground">
            Which department's Api-Key would you like to use?
          </p>
          <ChatDepartmentSelector disable={false} departments={props.departments}/>
        </div>
        
      </Card>
    </div>
  );
};


