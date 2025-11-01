import tables, sets, sequtils
import agent_message

type
  Subscriber* = object
    # Define subscriber properties, e.g., identifier, preferences, etc.

  Subscription* = object
    sender: string
    receiver: string
    topic: string

  MailingList* = object
    subscriptions: Table[Subscription, HashSet[Subscriber]]

proc initMailingList*(): MailingList =
  result.subscriptions = initTable[Subscription, HashSet[Subscriber]]()

proc subscribe*(list: var MailingList, subscription: Subscription, subscriber: Subscriber) =
  if not list.subscriptions.hasKey(subscription):
    list.subscriptions[subscription] = initHashSet[Subscriber]()
  list.subscriptions[subscription].incl(subscriber)

proc unsubscribe*(list: var MailingList, subscription: Subscription, subscriber: Subscriber) =
  if list.subscriptions.hasKey(subscription):
    list.subscriptions[subscription].excl(subscriber)

proc publishMessage*(list: MailingList, message: AgentMessage): seq[Subscriber] =
  # This function would filter subscribers based on the message criteria
  var result: seq[Subscriber] = @[]
  for sub, subs in list.subscriptions:
    if sub.sender == message.sender and sub.receiver == message.receiver and sub.topic == message.topic:
      result.add(subs.toSeq().flatten())
  return result

# Example usage
var mailingList = initMailingList()
# Add subscriptions and use publishMessage to get the list of subscribers for a message
