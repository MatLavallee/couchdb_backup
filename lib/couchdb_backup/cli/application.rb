require 'thor'
require 'couchrest'
require 'fileutils'
require 'fog'

module CouchdbBackup
  module Cli
    CLOUD_BACKUP_DIRECTORY_KEy = 'couchdb-backups-5484848984888489'

    class Application < Thor
      desc "replicate_database REMOTE_DB [LOCAL_DB]", "Replicate remote database to local CouchDB"
      def replicate_database(remote_db_url, local_db_url = nil)
        remote_db = CouchRest.database remote_db_url

        local_db_url ||= remote_db.name + '_' + digest(remote_db_url)
        local_db = CouchRest.database local_db_url

        puts "Starting replication from \"#{remote_db_url}\" to \"#{local_db_url}\""
        start_time = Time.now
        remote_db.replicate_to local_db, continuous = false, create_target = true
        puts "Replication completed in #{Time.now - start_time} s"
      end

      # TODO: Send compressed files to S3
      desc "backup", "Backup CouchDB data to cloud service"
      def backup
        file = zip_couchdb_data
        cloud_execute_backup file
      end

      # TODO: Restore from

      # TODO: Install as a cron job (support windows?)

      private

      def digest(string)
        require 'digest/md5'
        Digest::MD5.hexdigest string
      end

      def zip_couchdb_data
        temp_file = Tempfile.new "couchdb_backup"

        require 'zip/zip'
        Zip::ZipOutputStream.open temp_file.path do |zip_file|
          Dir[File.join(temp_file.path, '**', '**')].each do |file|
            zip_file.add file.sub(couchdb_data_path, ''), file
          end
        end

        temp_file
      end

      def couchdb_data_path
        if is_windows
          '/Program Files (x86)/Apache Software Foundation/CouchDB/var/lib/couchdb/'
        else
          '/var/lib/couchdb/'
        end
      end

      def is_windows
        require 'rbconfig'
        RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
      end

      def cloud_connection
        @cloud_connection ||= Fog::Storage.new({
                                                   :provider => 'Local',
                                                   :local_root => '/Temp/fog',
                                                   :endpoint => 'http://example.com'
                                               })
      end

      def cloud_execute_backup(file)
        file = File.open('/Temp/test2.zip')

        # Create or get a directory for backups
        directory = cloud_connection.directories.create(
            :key => CLOUD_BACKUP_DIRECTORY_KEy, # globally unique name
        )

        # Upload backup
        directory.files.create(
            :key => "couchdb-backup-#{Time.now.utc.strftime("%Y-%m-%d_%H-%M-%S_UTC")}.zip",
            :body => file
        )
      end
    end
  end
end