import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { FileText, MessageCircle } from "lucide-react";
import { FC } from "react";
import { ChatApiKey } from "../../chat-services/models";
import { useChatContext } from "../chat-context";
import { Select, SelectContent, SelectGroup, SelectItem, SelectTrigger, SelectValue, SelectLabel } from "@/components/ui/select";

interface Prop {
  disable: boolean;
}

export const ChatDepartmentSelector: FC<Prop> = (props) => {
  const { chatBody, onChatDepartmentChange } = useChatContext();

  return (
    <Select 
     defaultValue={chatBody.apiKey}
      disabled={props.disable}  
      onValueChange={(value) => onChatDepartmentChange(value as ChatApiKey)}
    >
      <SelectTrigger >
        <SelectValue 
          placeholder="Select department"
        />
      </SelectTrigger>
      <SelectContent>
        <SelectGroup>
          <SelectLabel>Departments</SelectLabel>
          <SelectItem value="Finance">Finance</SelectItem>
          <SelectItem value="Marketing">Marketing</SelectItem>
        </SelectGroup>
      </SelectContent>
    </Select>
  );
};
