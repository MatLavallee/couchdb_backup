require 'thor'
require 'couchrest'
require 'fileutils'
require 'tempfile'
require 'zip/zip'
require 'fog'

module CouchdbBackup
  module Cli
    class Application < Thor
      desc "backup REMOTE_DB_URL CLOUD_DIRECTORY", "Backup CouchDB data to cloud service"
      def backup(remote_db_url, cloud_directory)
        replicate_database remote_db_url
        file = zip_couchdb_data
        upload_cloud_backup file, cloud_directory
      end

      # TODO: Restore from

      # TODO: Install as a cron job (support windows?)

      private
      def replicate_database(remote_db_url)
        remote_db = CouchRest.database remote_db_url

        local_db_url = remote_db.name + '_' + digest(remote_db_url)
        local_db = CouchRest.database local_db_url

        puts "Starting replication from \"#{remote_db_url}\" to \"#{local_db_url}\""
        start_time = Time.now
        local_db.replicate_from remote_db, continuous = false, create_target = true
        puts "Replication completed in #{Time.now - start_time} s"
      end

      def digest(string)
        require 'digest/md5'
        Digest::MD5.hexdigest string
      end

      def zip_couchdb_data
        tempfile_path = File.join Dir.tmpdir, Dir::Tmpname.make_tmpname('couchdb_backup', '.zip')
        Zip::ZipFile.open tempfile_path, create = true do |zip_file|
          Dir[File.join(couchdb_data_path, '**', '**')].each do |file|
            zip_file.add file.sub(couchdb_data_path, ''), file
          end
        end
        File.open tempfile_path
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

      def upload_cloud_backup(file, directory_name)
        # Create or get a directory for backups
        directory = cloud_connection.directories.create(
            :key => directory_name, # globally unique name
        )

        # Upload backup
        puts "Uploading backup to #{directory_name}"
        directory.files.create(
            :key => "couchdb-backup-#{Time.now.utc.strftime('%Y-%m-%d_%H-%M-%S_UTC')}.zip",
            :body => file
        )
        puts 'Upload completed'
      end
    end
  end
end