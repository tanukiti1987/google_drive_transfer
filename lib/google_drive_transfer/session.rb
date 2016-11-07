class GoogleDriveTransfer::Session
  attr_reader :key

  def initialize(key)
    @key = key
  end

  def create
    puts "======================"
    puts "   Log in as #{key}   "
    puts "======================"
    session = GoogleDrive::Session.from_config("config_#{key}.json")
    puts "======================"
    puts "       Complete       "
    puts "======================"
    session
  end
end
