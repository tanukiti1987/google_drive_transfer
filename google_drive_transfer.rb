require "google_drive"
require "parallel"

class GoogleDriveTransfer
  DEFAULT_PARALLEL_NUM = 2

  attr_reader :source_session, :target_session, :logger

  def initialize(source_session, target_session)
    @source_session = source_session
    @target_session = target_session
    @logger = Logger.new('log')
  end

  def execute!
    source_root_collections = source_session.root_collection
    target_root_collections = target_session.root_collection

    source_files = source_root_collections.files.select {|f| is_file_or_spreadsheet?(f) }
    Parallel.each(source_files, in_thread: parallel_num) do |files|
      copy_collections(source: files, target: target_root_collections)
    end

    source_collections = source_root_collections.files.select {|f| is_collection?(f) }
    Parallel.each(source_collections, in_thread: parallel_num) do |collections|
      copy_collections(source: collections, target: target_root_collections)
    end
  end

  private

  def parallel_num
    (ENV['PARALLEL_NUM'] || DEFAULT_PARALLEL_NUM).to_i
  end

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

  def tmp_file_path(file)
    "tmp/#{file.id}-#{convert_title(file.title)}"
  end

  def transfer_spreadsheet(file, collection, path)
    STDOUT.puts "(from source) Downloading... #{path}#{convert_title(file.title)}"
    file.export_as_file(tmp_file_path(file), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

    STDOUT.puts "(to target) Uploading... #{path}#{convert_title(file.title)}"
    collection.upload_from_file(tmp_file_path(file), convert_title(file.title), convert: true)

    STDOUT.puts "Cleaning..."
    File.delete tmp_file_path(file)
    true
  end

  def transfer_file(file, collection, path)
    if file.available_content_types.empty?
      STDOUT.puts "Fail to transfer... #{path}#{convert_title(file.title)}"
      logger.error(convert_title(file.title))
      return false
    end

    STDOUT.puts "(from source) Downloading... #{path}#{convert_title(file.title)}"
    file.download_to_file(tmp_file_path(file))

    STDOUT.puts "(to target) Uploading... #{path}#{convert_title(file.title)}"
    upload_options = {
      content_type: file.available_content_types.first,
      convert: false
    }
    collection.upload_from_file(tmp_file_path(file), convert_title(file.title), upload_options)

    STDOUT.puts "Cleaning..."
    File.delete tmp_file_path(file)
    true
  end

  def transfer(file, collection, path)
    return false if is_collection?(file)

    if is_spreadsheet?(file)
      transfer_spreadsheet(file, collection, path)
    else
      transfer_file(file, collection, path)
    end
  rescue Google::Apis::ClientError => e
    STDOUT.puts "Fail to transfer... #{path}#{convert_title(file.title)}"
    logger.error(convert_title(file.title))
    return false
  rescue Google::Apis::ServerError => e
    sleep 60
    transfer(file, collection, path)
  end

  def is_collection?(file)
    file.class == GoogleDrive::Collection
  end

  def is_file_or_spreadsheet?(file)
    [GoogleDrive::File, GoogleDrive::Spreadsheet].include?(file.class)
  end

  def is_spreadsheet?(file)
    file.class == GoogleDrive::Spreadsheet
  end

  def convert_title(title)
    title.gsub('/', '-')
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
