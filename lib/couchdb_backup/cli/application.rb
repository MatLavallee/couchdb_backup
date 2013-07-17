require 'thor'
require 'couchrest'

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

      # TODO: Send compressed files to S3

      # TODO: Install as a cron job (support windows?)

      private

      def get_digest(string)
        require 'digest/md5'
        Digest::MD5.hexdigest string
      end
    end
  end
end