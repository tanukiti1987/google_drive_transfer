require "google_drive"

class GoogleDriveTransfer
  attr_reader :source_session, :target_session, :logger

  def initialize(source_session, target_session)
    @source_session = source_session
    @target_session = target_session
    @logger = Logger.new('log')
  end

  def execute!
    source_collection = source_session.root_collection
    target_collection = target_session.root_collection

    copy_collections(source: source_collection, target: target_collection)
  end

  private

  def copy_collections(source:, target:, path: '')
    if source.respond_to?(:files)
      source.files.each do |file|
        if is_collection?(file)
          STDOUT.puts "CREATE collection name: #{path}#{file.name}/"
          created_collection = target.create_subcollection(file.name)
          copy_collections(source: file, target: created_collection, path: "#{path}#{created_collection.title}/")
        else
          transfer(file, target, path)
        end
      end
    else
      transfer(source, target, path)
    end
  end

  def transfer(file, collection, path)
    return false unless is_file?(file)
    if file.available_content_types.empty?
      STDOUT.puts "Fail to transfer... #{path}#{file.title}"
      logger.error(file.title)
      return false
    end

    begin
      file_path = "tmp/#{file.title}"

      STDOUT.puts "(from source) Downloading... #{path}#{file.title}"
      file.download_to_file(file_path)

      STDOUT.puts "(to target) Uploading... #{path}#{file.title}"
      upload_options = {
        content_type: file.available_content_types.first,
        convert: false
      }
      collection.upload_from_file(file_path, file.title, upload_options)

      STDOUT.puts "Cleaning..."
      File.delete file_path
    rescue Google::Apis::ClientError => e
      STDOUT.puts "Fail to transfer... #{path}#{file.title}"
      logger.error(file.title)
      return false
    end
    true
  end

  def is_collection?(file)
    file.class == GoogleDrive::Collection
  end

  def is_file?(file)
    [GoogleDrive::File, GoogleDrive::Spreadsheet].include?(file.class)
  end
end

STDOUT.puts "======================"
STDOUT.puts "   Log in as source   "
STDOUT.puts "======================"
source_session = GoogleDrive::Session.from_config("config_source.json")
STDOUT.puts "======================"
STDOUT.puts "       Complete       "
STDOUT.puts "======================"


STDOUT.puts "======================"
STDOUT.puts "   Log in as target   "
STDOUT.puts "======================"
target_session = GoogleDrive::Session.from_config("config_target.json")
STDOUT.puts "======================"
STDOUT.puts "       Complete       "
STDOUT.puts "======================"

GoogleDriveTransfer.new(source_session, target_session).execute!
