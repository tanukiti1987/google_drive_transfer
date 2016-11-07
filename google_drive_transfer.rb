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

    copy_collections(source: source_root_collections, target: target_root_collections)
  end

  private

  def parallel_num
    (ENV['PARALLEL_NUM'] || DEFAULT_PARALLEL_NUM).to_i
  end

  def copy_collections(source:, target:, path: '')
    if source.respond_to?(:files)
      source_files = source.files.select {|f| is_file_or_spreadsheet?(f) }
      source_collections = source.files.select {|f| is_collection?(f) }

      Parallel.each(source_files, in_processes: parallel_num) do |file|
        transfer(file, target, path)
      end

      source_collections.each do |collection|
        STDOUT.puts "CREATE collection name: #{path}#{collection.name}/"
        created_collection = target.create_subcollection(collection.name)
        copy_collections(source: collection, target: created_collection, path: "#{path}#{created_collection.title}/")
      end
    else
      transfer(source, target, path)
    end
  end

  def tmp_file_path(file, extension: '')
    "tmp/#{file.id}-#{convert_title(file.title)}#{extension}"
  end

  # Document, Presentation も同じような感じでいけそう
  def transfer_spreadsheet(file, collection, path)
    STDOUT.puts "(from source) Downloading... #{path}#{convert_title(file.title)}"
    file.export_as_file(tmp_file_path(file, extension: '.xlsx'))

    STDOUT.puts "(to target) Uploading... #{path}#{convert_title(file.title)}"
    collection.upload_from_file(tmp_file_path(file, extension: '.xlsx'), convert_title(file.title))

    STDOUT.puts "Cleaning..."
    File.delete tmp_file_path(file, extension: '.xlsx')
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
    STDOUT.puts "Fail to transfer... #{path}#{convert_title(file.title)}"
    STDOUT.puts "Retry after 1 minute"
    sleep 60
    transfer(file, collection, path)
  rescue Errno::ECONNRESET => e
    STDOUT.puts "Fail to transfer... #{path}#{convert_title(file.title)}"
    STDOUT.puts "Retry after 1 minute"
    sleep 60
    transfer(file, collection, path)
  rescue Errno::ENOENT => e
    STDOUT.puts "Fail to transfer... #{path}#{convert_title(file.title)}"
    logger.error(convert_title(file.title))
    return false
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
