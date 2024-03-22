"use client";

import { FC } from "react";
import { useChatContext } from "./chat-context";
import { ChatMessageEmptyState } from "./chat-empty-state/chat-message-empty-state";
import ChatInput from "./chat-input/chat-input";
import { ChatMessageContainer } from "./chat-message-container";
import { DepartmentConfig, DeploymentConfig } from "../chat-services/models";

interface Prop {
  deployments: DeploymentConfig[];
  departments: DepartmentConfig[];
}

export const ChatUI: FC<Prop> = (props) => {
  const { messages } = useChatContext();
  
  return (
    <div className="h-full relative overflow-hidden flex-1 bg-card rounded-md shadow-md">
      {messages.length !== 0 ? (
        <ChatMessageContainer />
      ) : (
        <ChatMessageEmptyState deployments={props.deployments} departments={props.departments}/>
      )}

      <ChatInput />
    </div>
  );
};
