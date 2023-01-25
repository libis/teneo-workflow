# frozen_string_literal: true

require 'digest'

module Teneo
  module Workflow
    module FileItem

      def self.included(klass)
        klass.include WorkItem
      end

      def fullpath
        properties[:filename] || name
      end

      def filename
        File.basename(fullpath)
      end

      def filename=(file)
        delete_file
        properties[:filename] = file
        self.name = File.basename(file) if self.name.nil? or self.name.blank?

        return unless File.exist?(file)

        stats = ::File.stat file
        properties[:size] = stats.size
        properties[:modification_time] = stats.mtime

        checksum :MD5, true
      end

      def own_file(v = true)
        properties[:owns_file] = v
      end

      def filelist
        (parent&.filelist || []).push(filename).compact
      end

      def filepath
        filelist.join('/')
      end

      # value is String or true to force recalculate or false to delete
      # calculates the checksum if not known unless value is false
      def checksum(checksum_type, value = nil)
        key = "checksum_#{checksum_type}".downcase.to_sym
        case value
        when FalseClass
          properties.delete(key) if value == false
          return nil
        when TrueClass
          properties.delete(key) if value == false
        when String
          properties[key] = value
        end
        file = properties[:filename]
        properties[key] ||= ::Teneo::Tools::Checksum.hexdigest(file, checksum_type) if File.file?(file)
        properties[key]
      end

      def link
        properties[:link]
      end

      def link=(name)
        properties[:link] = name
      end

      def info=(info)
        info.each do |k, v|
          properties[k] = v
        end
      end

      def key_names
        %i'filename size modification_time owns_file'
      end

      def delete_file
        if properties[:owns_file] && fullpath
          File.delete(fullpath) if File.exists?(fullpath)
        end
        properties.keys
          .select { |key| key_names.include?(key) || key.to_s =~ /^checksum_/ }
          .each { |key| properties.delete(key) }
      end
    end
  end
end
