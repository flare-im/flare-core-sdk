import fs from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

import {
  conversationFromJson,
  conversationParticipantFromJson,
  displayNameFromJson,
  displayNameToMap,
  messageFromJson,
} from "../src/adapter/codec/wireCodec";
import { DisplayNameKind } from "../src/model/display_name_kind";
import { NameEntity } from "../src/model/name_entity";

const specDir = path.resolve(process.cwd(), "../../sdk-spec/golden");

function readJson(relative: string): Record<string, unknown> {
  return JSON.parse(fs.readFileSync(path.join(specDir, relative), "utf8")) as Record<string, unknown>;
}

type ProjectionCase = { name: string; expected: Record<string, unknown> };

/** Every DisplayName the core projects in display-name-projection.json, people first. */
function projectedNames(): ProjectionCase[] {
  const vectors = readJson("display-name-projection.json") as { people: ProjectionCase[]; conversations: ProjectionCase[] };
  const cases = [...vectors.people, ...vectors.conversations];
  expect(cases.length).toBeGreaterThan(0);
  return cases;
}

function participant(userId: string, name?: unknown): Record<string, unknown> {
  return {
    userId,
    roles: [],
    muted: false,
    pinned: false,
    attributes: {},
    joinedAt: 0,
    nickname: "",
    ...(name !== undefined ? { name } : {}),
  };
}

const unknownPerson = { kind: DisplayNameKind.Unnamed, entity: NameEntity.Person, idTail: "" };

describe("DisplayName wire codec", () => {
  it("decodes every projected name in display-name-projection.json as the core wrote it", () => {
    for (const { name, expected } of projectedNames()) {
      const decoded = displayNameFromJson(expected);
      expect(decoded, name).toEqual(expected);
      expect(displayNameToMap(decoded!), name).toEqual(expected);
    }
  });

  it("reads title, lastSender, sender and participant names from the values the core hands over", () => {
    for (const { name, expected } of projectedNames()) {
      const conversation = conversationFromJson({
        ...readJson("responses/conversation_get_one.json"),
        title: expected,
        lastSender: expected,
        memberPreview: [participant("u2", expected)],
        participants: [participant("u3", expected)],
      });
      expect(conversation.title, name).toEqual(expected);
      expect(conversation.lastSender, name).toEqual(expected);
      expect(conversation.memberPreview[0].name, name).toEqual(expected);
      expect(conversation.participants[0].name, name).toEqual(expected);

      const message = messageFromJson({ ...readJson("responses/build_thread_reply_message.json"), sender: expected });
      expect(message.sender, name).toEqual(expected);
    }
  });

  it("requires the names every value carries and leaves lastSender out without a latest message", () => {
    const { title: _title, ...untitled } = readJson("responses/conversation_get_one.json");
    expect(() => conversationFromJson(untitled)).toThrow("Conversation.title is required");
    expect(() => conversationFromJson({ ...untitled, title: null })).toThrow("Conversation.title is required");
    const conversation = conversationFromJson(readJson("responses/conversation_get_one.json"));
    expect(conversation.title).toEqual({ kind: DisplayNameKind.Named, text: "User Two", source: "profile" });
    expect("lastSender" in conversation).toBe(false);

    const { sender: _sender, ...unsent } = readJson("responses/build_thread_reply_message.json");
    expect(() => messageFromJson(unsent)).toThrow("Message.sender is required");

    expect(() => conversationParticipantFromJson(participant("u2"))).toThrow("ConversationParticipant.name is required");
    expect(() =>
      conversationFromJson({ ...readJson("responses/conversation_get_one.json"), memberPreview: [participant("u2")] }),
    ).toThrow("ConversationParticipant.name is required");

    expect(displayNameFromJson(undefined)).toBeUndefined();
    expect(displayNameFromJson(null)).toBeUndefined();
  });

  it("reads a kind it does not know as an unnamed person without an id tail", () => {
    expect(displayNameFromJson({ kind: "nickname", text: "Alice" })).toEqual(unknownPerson);
    expect(displayNameFromJson({ text: "Alice" })).toEqual(unknownPerson);
    const conversation = conversationFromJson({
      ...readJson("responses/conversation_get_one.json"),
      title: { kind: "emoji", value: ":)" },
    });
    expect(conversation.title).toEqual(unknownPerson);
  });

  it("reads an entity it does not know as a person and keeps the id tail", () => {
    expect(displayNameFromJson({ kind: "unnamed", entity: "robot", idTail: "9876" })).toEqual({
      kind: DisplayNameKind.Unnamed,
      entity: NameEntity.Person,
      idTail: "9876",
    });
    expect(displayNameFromJson({ kind: "unnamed" })).toEqual(unknownPerson);
    const message = messageFromJson({
      ...readJson("responses/build_thread_reply_message.json"),
      sender: { kind: "unnamed", entity: "bot", idTail: "0401" },
    });
    expect(message.sender).toEqual({ kind: DisplayNameKind.Unnamed, entity: NameEntity.Person, idTail: "0401" });
  });

  it("reads malformed names without failing the value that carries them", () => {
    expect(displayNameFromJson("Alice")).toEqual(unknownPerson);
    expect(displayNameFromJson(["Alice"])).toEqual(unknownPerson);
    expect(displayNameFromJson({ kind: "named" })).toEqual(unknownPerson);
    expect(displayNameFromJson({ kind: "named", text: "Alice", source: "nickname" })).toEqual({
      kind: DisplayNameKind.Named,
      text: "Alice",
    });
    expect(displayNameFromJson({ kind: "members", names: ["Ann", 3, "Ben"], total: 4.7 })).toEqual({
      kind: DisplayNameKind.Members,
      names: ["Ann", "Ben"],
      total: 4,
    });
    expect(displayNameFromJson({ kind: "members", total: -1 })).toEqual({ kind: DisplayNameKind.Members, names: [], total: 0 });
    expect(displayNameFromJson({ kind: "unnamed", entity: "group", idTail: 12 })).toEqual({
      kind: DisplayNameKind.Unnamed,
      entity: NameEntity.Group,
      idTail: "",
    });
  });
});
