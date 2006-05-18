desc "Cleanup Backup files"
task 'backups:clear' => :environment do
  Dir["#{RAILS_ROOT}/**/*.*~"].each {|file| File.delete(file)}
end

desc "Clears all files in tmp/test/assets"
task 'tmp:assets:clear' => :environment do
  FileUtils.rm_rf(Dir['tmp/test/css/[^.]*'])
  FileUtils.rm_rf(Dir['tmp/test/markup/[^.]*'])
  FileUtils.rm_rf(Dir['tmp/test/test/[^.]*'])
end

Rake::Task['tmp:clear'].enhance(['tmp:assets:clear'])

desc "Cleanup temporary, log and backup files"
task :clear => ['tmp:clear', 'backups:clear', 'log:clear'] do
end
