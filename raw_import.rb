#!/usr/bin/env ruby
require 'fileutils'
require 'optparse'
require 'win32ole'

$opts = {}
OptionParser.new do |opts|
  opts.banner = "Usage: raw_import [options]"

  opts.on("--cam_prefix PREFIX", "Set camera prefix") do |prefix|
	$opts[:cam_prefix] = prefix
  end
end.parse!

CARD_LABELS=%w[EOS_DIGITAL DJI]
SOURCE_GLOB="DCIM/**/*"

CAM_PREFIX="cam_prefix"
MAX_PREFIX=32

LAST_IMPORT="last_import"

IMPORT_PATH="D:/RAW"
IMPORT_EXTS=%w(.CRW .CR2 .CR3 .MOV .MP4 .JPG .DNG)
CONDITIONAL_IMPORT_EXTS=%w(.JPG) # only import if another file with the same basename does not exist

# avoid splitting photo sessions that cross midnight if a photo on the new day is taken within 3 hours of the previous one
NIGHT_BATCH_GAP=60*60*3

class FileInfo
	attr_reader :path, :ext, :basename, :time

	def initialize(path)
		@path = path
		@ext = File.extname(path)
		@basename = File.basename(path, ext)
		@time = File.birthtime(path)
	end

	def name
		basename + ext
	end

	def date
		@date ||= @time.strftime('%F')
	end
end

class CardInfo
	def self.card_path
		@card_path ||= begin
			file_system = WIN32OLE.new("Scripting.FileSystemObject")
			drive = nil # dumb thing doesn't support `detect` 
			file_system.Drives.each do |d|
				next unless d.IsReady
				if CARD_LABELS.include?(d.VolumeName)
					drive = d
					break
				end
			end
			unless drive
				puts "Memory card not found"
				exit 1
			end
			puts "Found memory card #{drive.VolumeName} at path #{drive.Path}"
			drive.path
		end
	end

	def self.source_glob
		File.join(card_path, SOURCE_GLOB)
	end

	def self.cam_prefix
		prefix_frd.length > 0 ? prefix_frd : nil
	end

	def self.transform_name(filename)
		cam_prefix ? filename.sub(/^[A-Z]+_/, "#{cam_prefix}_") : filename
	end

	def self.last_import
		Time.at(File.read(File.join(card_path, LAST_IMPORT)).to_i)
	rescue
		nil
	end

	def self.last_import=(time)
		File.write(File.join(card_path, LAST_IMPORT), time.to_i.to_s)
	end

	def self.prefix_frd
		@prefix ||= begin
			File.read(File.join(card_path, CAM_PREFIX)).strip[0, MAX_PREFIX]
		rescue
			''
		end
	end
end

def split_batch?(batch, file)
	if batch.last.date == file.date
		# split in the middle of a day if the batch already spans a day and X hours have passed
		batch.first.date != file.date && file.time - batch.last.time > NIGHT_BATCH_GAP
	else
		# split on a day boundary if X hours have passed (to avoid splitting a late night batch)
		file.time - batch.last.time > NIGHT_BATCH_GAP
	end
end

def find_source_batches(since)
	filenames = Dir.glob(CardInfo.source_glob).select { |ent| IMPORT_EXTS.include?(File.extname(ent)) }
	files = filenames.map { |fname| FileInfo.new(fname) }
	files.select! { |file| file.time > since } if since
	return nil if files.empty?
	files.sort_by!(&:time)

	batch = [files.shift]
	batches = [batch]
	files.each do |file|
		if split_batch?(batch, file)
			batch = [file]
			batches << batch
		else
			batch << file
		end
	end
	batches
end

def batch_path(batch)
	File.join(IMPORT_PATH, batch.first.time.strftime("%Y/%m/%d"))
end

if ARGV[0] =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/
	start = Time.new($1, $2, $3)
else
	start = CardInfo.last_import
end
puts "Importing files created after #{start.to_s}" if start

prefix = $opts[:cam_prefix]
prefix ||= CardInfo.cam_prefix
puts "Using camera prefix: #{prefix}" if prefix

puts

batches = find_source_batches(start)
unless batches
	puts "Nothing to import"
	exit 1
end

batches.each do |batch|
	dest_dir = batch_path(batch)
	puts dest_dir
	FileUtils.mkdir_p(dest_dir)
	batch.reject! { |file| CONDITIONAL_IMPORT_EXTS.include?(file.ext) &&
	                       batch.any? { |other_file| other_file.basename == file.basename && other_file.ext != file.ext } }
	batch.each do |file|
		name = CardInfo.transform_name(file.name)
		src_file = file.path
		dest_file = File.join(dest_dir, name)
		
		if File.exists?(dest_file)
			puts "#{name} already exists - skipping"
		else
			puts "#{name} #{file.time}"
			FileUtils.cp(src_file, dest_file, preserve: true)
		end
	end
	puts
end

CardInfo.last_import = batches.last.last.time
puts "Saved last import time #{CardInfo.last_import}"

puts
puts "Import summary:"
batches.each do |batch|
	puts "  #{batch_path(batch)}: #{batch.size} files"
	puts "    oldest: #{CardInfo.transform_name(batch.first.name)} #{batch.first.time}"
	puts "    newest: #{CardInfo.transform_name(batch.last.name)} #{batch.last.time}"
	puts
end
