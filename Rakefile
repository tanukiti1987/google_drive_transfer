desc "タスクの説明です。"
task :setup do
  unless File.exist?('log')
    FileUtils.touch('log')
  end

  STDOUT.puts "Input your Google API client_id: "
  client_id = STDIN.gets.strip
  if client_id.empty?
    STDOUT.puts "Blank client_id... Quit settings."
    next
  end

  STDOUT.puts "Input your Google API client_secret: "
  client_secret = STDIN.gets.strip
  if client_secret.empty?
    STDOUT.puts "Blank client_secret... Quit settings."
    next
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
