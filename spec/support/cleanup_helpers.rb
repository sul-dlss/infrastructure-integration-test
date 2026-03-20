# frozen_string_literal: true

module CleanupHelpers
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def track_created_objects
      before do
        @created_druids = []
        @temp_files = []
      end

      after do
        cleanup_created_objects
        cleanup_temp_files
      end
    end
  end

  def track_druid(druid)
    @created_druids ||= []
    @created_druids << druid
    puts "Tracking DRUID for cleanup: #{druid}"
  end

  def track_temp_file(file_path)
    @temp_files ||= []
    @temp_files << file_path
  end

  def cleanup_created_objects
    return unless @created_druids&.any?

    puts "Cleaning up #{@created_druids.length} tracked test objects..."
    @created_druids.each do |druid|
      cleanup_object(druid)
    end
  end

  def cleanup_temp_files
    return unless @temp_files&.any?

    @temp_files.each do |file_path|
      if File.exist?(file_path)
        File.delete(file_path)
        puts "Cleaned up temp file: #{file_path}"
      end
    end
  end

  private

  def cleanup_object(druid)
    # Add cleanup logic for objects created in Argo
    # For now, just log cleanup intention
    # In future, this could involve API calls to delete or mark objects as test data
    puts "Would clean up test object: #{druid} (implement API cleanup as needed)"
  rescue => e
    puts "Error cleaning up object #{druid}: #{e.message}"
  end
end

RSpec.configure { |config| config.include CleanupHelpers }
