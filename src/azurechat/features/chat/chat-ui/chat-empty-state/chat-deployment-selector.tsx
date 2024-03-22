import { FC } from "react";
import { ChatDeployment, DeploymentConfig } from "../../chat-services/models";
import { useChatContext } from "../chat-context";
import { Select, SelectContent, SelectGroup, SelectItem, SelectTrigger, SelectValue, SelectLabel } from "@/components/ui/select";

interface Prop {
  disable: boolean;
  deployments: DeploymentConfig[];
}

export default function ListDeployments(deployments : DeploymentConfig[]) : any {
    const chatDeployments = deployments.filter(d => d.type == "chat");
    const listItems = chatDeployments.map((deployment) =>
      <SelectItem 
        value={deployment.deployment}>
          {deployment.deployment}
      </SelectItem>
    );
    return listItems;

  };





export const ChatDeploymentSelector: FC<Prop> = (props) => {
  const { chatBody, onChatDeploymentChange } = useChatContext();

  return (
    
    <Select 
     defaultValue={chatBody.deployment}
      disabled={props.disable}  
      onValueChange={(value) => onChatDeploymentChange(value as ChatDeployment)}
    >
      <SelectTrigger >
        <SelectValue 
          placeholder="Select deployment"
        />
      </SelectTrigger>

      <SelectContent>
        <SelectGroup>{ListDeployments(props.deployments)}</SelectGroup>
      </SelectContent>
      
    </Select>
    
  );
};
 