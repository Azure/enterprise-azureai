import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { FileText, MessageCircle } from "lucide-react";
import { FC } from "react";
import { ChatDeployment } from "../../chat-services/models";
import { useChatContext } from "../chat-context";
import { Select, SelectContent, SelectGroup, SelectItem, SelectTrigger, SelectValue, SelectLabel } from "@/components/ui/select";

interface Prop {
  disable: boolean;
}

export const ChatDeploymentSelector: FC<Prop> = (props) => {
  const { chatBody, onChatDeploymentChange } = useChatContext();

  return (
    <Select 
     defaultValue={chatBody.chatDeployment}
      disabled={props.disable}  
      onValueChange={(value) => onChatDeploymentChange(value as ChatDeployment)}
    >
      <SelectTrigger >
        <SelectValue 
          placeholder="Select deployment"
        />
      </SelectTrigger>
      <SelectContent>
        <SelectGroup>
          <SelectLabel>Deployments</SelectLabel>
          <SelectItem value="gpt-35-turbo">gpt-35-turbo</SelectItem>
          <SelectItem value="gpt-35-turbo-lowpolicy">gpt-35-turbo-lowpolicy</SelectItem>
        </SelectGroup>
      </SelectContent>
    </Select>
  );
};
