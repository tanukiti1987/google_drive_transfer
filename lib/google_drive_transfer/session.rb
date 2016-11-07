class GoogleDriveTransfer::Session
  attr_reader :key

  def initialize(key)
    @key = key
  end

  def create
    STDOUT.puts "======================"
    STDOUT.puts "   Log in as #{key}   "
    STDOUT.puts "======================"
    session = GoogleDrive::Session.from_config("config_#{key}.json")
    STDOUT.puts "======================"
    STDOUT.puts "       Complete       "
    STDOUT.puts "======================"
    session
  end
end
