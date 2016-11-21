require "thor"

module GoogleDriveTransfer
  class CLI < Thor
    desc "start", "start to transfer."
    def start
      source_session = GoogleDriveTransfer::Session.new('source').create
      target_session = GoogleDriveTransfer::Session.new('target').create
      GoogleDriveTransfer::Executer.new(
        source_session: source_session,
        target_session:target_session)
      .execute!
    end

    desc "setup", "setup your authorization info."
    def setup
      unless File.exist?('log')
        FileUtils.touch('log')
      end

      unless File.exist?('correspondence_table.txt')
        FileUtils.touch('correspondence_table.txt')
      end

      puts "Input your Google API client_id: "
      client_id = STDIN.gets.strip
      if client_id.empty?
        puts "Blank client_id... Quit settings."
        return
      end

      puts "Input your Google API client_secret: "
      client_secret = STDIN.gets.strip
      if client_secret.empty?
        puts "Blank client_secret... Quit settings."
        return
      end

      erb = File.read("templates/config.json.erb")
      output = ERB.new(erb).result(binding)

      %w[source target].each do |suffix|
        unless File.exist?("config_#{suffix}.json")
          File.open("config_#{suffix}.json", "w") do |f|
            f.puts(output)
          end
        end
      end
    end
  end
end
