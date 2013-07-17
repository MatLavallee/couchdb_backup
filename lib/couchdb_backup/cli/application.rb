require 'thor'
require 'couchrest'
require 'fileutils'

module CouchdbBackup
  module Cli
    class Application < Thor
      desc "replicate_database REMOTE_DB [LOCAL_DB]", "Replicate remote database to local CouchDB"
      def replicate_database(remote_db_url, local_db_url = nil)
        remote_db = CouchRest.database remote_db_url

        local_db_url ||= remote_db.name + '_' + get_digest(remote_db_url)
        local_db = CouchRest.database local_db_url

        puts "Starting replication from \"#{remote_db_url}\" to \"#{local_db_url}\""
        start_time = Time.now
        remote_db.replicate_to local_db, continuous = false, create_target = true
        puts "Replication completed in #{Time.now - start_time} s"
      end

      # TODO: Compress CouchDB files
      desc "compress", "Compress"
      def compress
        zip_couchdb_files
      end

      # TODO: Send compressed files to S3

      # TODO: Install as a cron job (support windows?)

      private

      def get_digest(string)
        require 'digest/md5'
        Digest::MD5.hexdigest string
      end

      def is_windows
        require 'rbconfig'
        RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
      end

      def zip_couchdb_files
        database_files = if is_windows
                           '/Program Files (x86)/Apache Software Foundation/CouchDB/var/lib/couchdb/'
                         else
                           '/var/lib/couchdb/'
                         end
        zip_directory database_files
      end

      def zip_directory(directory_path)
        temp_file = Tempfile.new "couchdb_backup"

        require 'zip/zip'
        Zip::ZipOutputStream.open temp_file.path do |zip_file|
          Dir[File.join(temp_file.path, '**', '**')].each do |file|
            zip_file.add file.sub(directory_path, ''), file
          end
        end

        temp_file.close

        temp_file
      end
    end
  end
end