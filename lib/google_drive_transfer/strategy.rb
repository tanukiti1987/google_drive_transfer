require 'yaml'

class GoogleDriveTransfer::Strategy
  def self.skip_collections?(name)
    config["skip_collections"].include?(name)
  end

  private

  def self.config
    @@config ||= YAML.load_file('transfer_strategy.yml')
  end
end
