# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import nima

test "can create message":
  var msg: Message = (sender:1, receiver:2, topic:"hello")
  check msg.sender == 1
  check msg.receiver == 2
  check msg.topic == "hello"
  msg_copy = msg.copy()
  

test "can create agent":
  var agent = newAgent()
  check agent.id == 1

test "minimal system":
  var agent = newAgent()
  var s = newScheduler()
  s.add(agent)
  s.run()
  check s.t == 1