import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { FileText, MessageCircle } from "lucide-react";
import { FC } from "react";
import { ChatApiKey, DepartmentConfig } from "../../chat-services/models";
import { useChatContext } from "../chat-context";
import { Select, SelectContent, SelectGroup, SelectItem, SelectTrigger, SelectValue, SelectLabel } from "@/components/ui/select";

interface Prop {
  disable: boolean;
  departments: DepartmentConfig[];
}

export default function ListDepartments(departments : DepartmentConfig[]) : any {
  //const sortedDepartments = departments.sort();
  const listItems = departments.map((department) =>
    <SelectItem 
      value={department.name}>
        {department.name}
    </SelectItem>
  );
  return listItems;

};

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
        <SelectGroup>{ListDepartments(props.departments)}</SelectGroup>
      </SelectContent>
      
    </Select>
  );
};
