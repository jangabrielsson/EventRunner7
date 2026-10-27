-- Rules file for tests/fqa_test.lua — loaded as the fqa's 'pl' file.

print("OKOKOK")
function main(er)
  local rule = er.eval
  print("OKOK")
  rule("@@00:00:05 => log('tick!')",{check=false})
end