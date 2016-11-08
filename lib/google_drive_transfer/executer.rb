require "parallel"

class GoogleDriveTransfer::Executer
  DEFAULT_PARALLEL_NUM = 2

  attr_reader :source_session, :target_session, :logger

  def initialize(source_session:, target_session:)
    @source_session = source_session
    @target_session = target_session
    @logger = Logger.new('log')
    @backoff_time = 0
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
        next if GoogleDriveTransfer::Strategy.skip_collections?(collection.name)

        puts "CREATE collection name: #{path}#{collection.name}/"
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

  def transfer_spreadsheet(file, collection, path)
    puts "(from source) Downloading... #{path}#{convert_title(file.title)}"
    file.export_as_file(tmp_file_path(file, extension: '.xlsx'))

    puts "(to target) Uploading... #{path}#{convert_title(file.title)}"
    uploaded_file = collection.upload_from_file(tmp_file_path(file, extension: '.xlsx'), convert_title(file.title))
    if file.trashed?
      uploaded_file.delete
    end

    puts "Cleaning..."
    File.delete tmp_file_path(file, extension: '.xlsx')
    true
  end

  def transfer_file(file, collection, path)
    file_path = tmp_file_path(file)
    if file.available_content_types.empty?
      case file.mime_type
      when 'application/vnd.google-apps.document'
        begin
          FileUtils.touch(file_path)
          io = File.open(file_path, 'r+')
          puts "(from source) Downloading... #{path}#{convert_title(file.title)}"
          file.export_to_io(io, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
          puts "(to target) Uploading... #{path}#{convert_title(file.title)}"
          uploaded_file = collection.upload_from_io(io, convert_title(file.title), content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', convert: true)
          if file.trashed?
            uploaded_file.delete
          end
        ensure
          puts "(to target) Uploaded!"
          io.close
          File.delete file_path
        end
      when 'application/vnd.google-apps.presentation'
        begin
          FileUtils.touch(file_path)
          io = File.open(file_path, 'r+')
          puts "(from source) Downloading... #{path}#{convert_title(file.title)}"
          file.export_to_io(io, 'application/vnd.openxmlformats-officedocument.presentationml.presentation')
          puts "(to target) Uploading... #{path}#{convert_title(file.title)}"
          uploaded_file = collection.upload_from_io(io, convert_title(file.title), content_type: 'application/vnd.openxmlformats-officedocument.presentationml.presentation', convert: true)
          if file.trashed?
            uploaded_file.delete
          end
        ensure
          puts "(to target) Uploaded!"
          io.close
          File.delete file_path
        end
      else
        puts "Fail to transfer... #{path}#{convert_title(file.title)}"
        logger.error("#{path}#{convert_title(file.title)}")
        return false
      end
    else
      begin
        content_type = file.available_content_types.first
        puts "(from source) Downloading... #{path}#{convert_title(file.title)}"
        file.download_to_file(file_path)

        puts "(to target) Uploading... #{path}#{convert_title(file.title)}"
        upload_options = {
          content_type: content_type,
          convert: false,
        }
        uploaded_file = collection.upload_from_file(file_path, convert_title(file.title), upload_options)
        if file.trashed?
          uploaded_file.delete
        end
      ensure
        puts "(to target) Uploaded!"
        File.delete file_path
      end
    end
  end

  def transfer(file, collection, path)
    return false if is_collection?(file)

    if is_spreadsheet?(file)
      transfer_spreadsheet(file, collection, path)
    else
      transfer_file(file, collection, path)
    end
    reset_backoff
  rescue Google::Apis::ClientError => e
    puts "Fail to transfer... #{path}#{convert_title(file.title)}"
    logger.error("#{path}#{convert_title(file.title)}")
    return false
  rescue Google::Apis::ServerError => e
    wating_time = extend_backoff_time
    puts "Fail to transfer... #{path}#{convert_title(file.title)}"
    puts "Retry after #{wating_time} second(s)."
    sleep wating_time
    transfer(file, collection, path)
  rescue Google::Apis::RateLimitError => e
    wating_time = extend_backoff_time
    puts "Fail to transfer... #{path}#{convert_title(file.title)}"
    puts "Retry after #{wating_time} second(s)."
    sleep wating_time
    transfer(file, collection, path)
  rescue Errno::ECONNRESET => e
    wating_time = extend_backoff_time
    puts "Fail to transfer... #{path}#{convert_title(file.title)}"
    puts "Retry after #{wating_time} second(s)."
    sleep wating_time
    transfer(file, collection, path)
  rescue Errno::ENOENT => e
    puts "Fail to transfer... #{path}#{convert_title(file.title)}"
    logger.error("#{path}#{convert_title(file.title)}")
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

  def extend_backoff_time
    if @backoff_time != 0
      @backoff_time = @backoff_time * 2
    else
      @backoff_time = 1
    end
  end

  def reset_backoff
    @backoff_time = 0
  end
end
