require 'thor'
require 'couchrest'
require 'fileutils'
require 'tempfile'
require 'zip/zip'
require 'fog'

module CouchdbBackup
  module Cli
    class Application < Thor
      desc 'backup REMOTE_DB_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY CLOUD_DIRECTORY',
           'Backup CouchDB data to cloud service'
      def backup(remote_db_url, aws_access_key_id, aws_secret_access_key, cloud_directory)
        # Replicate DB
        replicate_database remote_db_url

        # Zip data
        file = zip_couchdb_data

        # Upload backup file
        cloud_connection = cloud_connection(aws_access_key_id, aws_secret_access_key)
        upload_cloud_backup(file, cloud_connection, cloud_directory)
      end

      desc 'restore REMOTE_DB_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY CLOUD_DIRECTORY',
           'Restore CouchDB data from cloud service'
      def restore(remote_db_url, aws_access_key_id, aws_secret_access_key, cloud_directory, backup_filename)
        # Download backup file
        cloud_connection = cloud_connection(aws_access_key_id, aws_secret_access_key)
        backup_file = download_cloud_backup(cloud_connection, cloud_directory, backup_filename)

        ## Unzip data
        #file = zip_couchdb_data
        #
        ## Replicate DB
        #replicate_database remote_db_url
      end

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

      def cloud_connection(aws_access_key_id, aws_secret_access_key)
        Fog::Storage.new({
                             :provider => 'AWS',
                             :aws_access_key_id => aws_access_key_id,
                             :aws_secret_access_key => aws_secret_access_key
                         })
      end

      def upload_cloud_backup(file, cloud_connection, directory_name)
        # Create or get a directory for backups
        directory = cloud_connection.directories.create(
            :key => directory_name, # globally unique name
        )

        # Upload backup
        puts "Uploading backup to #{directory_name}"
        start_time = Time.now
        directory.files.create(
            :key => "couchdb-backup-#{Time.now.utc.strftime('%Y-%m-%d_%H-%M-%S_UTC')}.zip",
            :body => file
        )
        puts "Upload completed in #{Time.now - start_time} s"
      end

      def download_cloud_backup(cloud_connection, directory_name, backup_filename)
        # Create or get a directory for backups
        directory = cloud_connection.directories.create(
            :key => directory_name, # globally unique name
        )

        # Download backup
        puts "Download backup #{directory_name}/#{backup_filename}"
        start_time = Time.now
        directory.files.get(backup_filename)
        puts "Download completed in #{Time.now - start_time} s"
      end
    end
  end
end