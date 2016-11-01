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

  def copy_collections(source:, target:)
    if source.respond_to?(:files)
      source.files.each do |file|
        if is_collection?(file)
          p "CREATE collection name: #{file.name}"
          created_collection = target.create_subcollection(file.name)
          copy_collections(source: file, target: created_collection)
        else
          transfer(file, target)
        end
      end
    else
      transfer(source, target)
    end
  end

  def transfer(file, collection)
    return false unless is_file?(file)
    if file.available_content_types.empty?
      p "Fail to transfer... #{file.title}"
      logger.error(file.title)
      return false
    end

    begin
      file_path = "tmp/#{file.title}"

      p "(from source) Downloading... #{file.title}"
      file.download_to_file(file_path)

      p "(to target) Uploading... #{file.title}"
      upload_options = {
        content_type: file.available_content_types.first,
        convert: false
      }
      collection.upload_from_file(file_path, file.title, upload_options)

      p "Cleaning..."
      File.delete file_path
    rescue Google::Apis::ClientError => e
      p "Fail to transfer... #{file.title}"
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

p "======================"
p "   Log in as source   "
p "======================"
source_session = GoogleDrive::Session.from_config("config_source.json")
p "======================"
p "       Complete       "
p "======================"


p "======================"
p "   Log in as target   "
p "======================"
target_session = GoogleDrive::Session.from_config("config_target.json")
p "======================"
p "       Complete       "
p "======================"

GoogleDriveTransfer.new(source_session, target_session).execute!
