# Generate large YAML file
# 
# Usage:
#
#   ruby bigboy.rb > yaml/bigboy.yaml
#

lorem = "lorem ipsum dolor sit amet consectetur adipisicing elit sed do eiusmod " \
        "tempor incididunt ut labore et dolore magna aliqua ut enim minim veniam " \
        "quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo " \
        "consequat duis aute irure dolor in reprehenderit in voluptate velit esse " \
        "cillum dolore eu fugiat nulla pariatur excepteur sint occaecat cupidatat " \
        "non proident sunte culpa qui officia deserunt".split

# 2000 ~ 10MB
(3 * 2000).times do |i|
  puts "- foo: bar"
  puts "- #{lorem.shuffle.first}: #{lorem.shuffle.join(' ')}"
  lorem.shuffle[0..10].each do |k|
    puts "  #{k}: #{lorem.shuffle.join(' ')}"
  end
end
