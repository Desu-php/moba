--!strict
local R=require("../src/shared/Game/DeveloperCommandRules")
for _,text in {"level 1","level 30","  LEVEL 12  ","/dev level 30","nocd on","nocd off","refresh","learnall","solo","help"} do assert(R.parse(text),text) end
for _,text in {"level 0","level 31","level -1","level 2.5","level nan","level inf","level 30 other","nocd yes","refresh other","print(1)",string.rep("a",101),""} do assert(R.parse(text)==nil,text) end
assert(R.parse({})==nil and R.parse(30)==nil)
assert((R.parse("nocd off") :: R.Command).enabled==false)
print("PASS developer commands: bounded whitelist, numeric limits and malformed arguments")
