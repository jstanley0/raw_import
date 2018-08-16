#!/usr/bin/env ruby

SOURCE_PATH="G:/DCIM/100CANON"

IMPORT_PATH="D:/RAW"
IMPORT_EXTS=%w(.CRW .CR2 .CR3 .MOV .MP4 .JPG)

PROCESSED_PATH="D:/_photo"
PROCESS_EXT_MAP={'.CRW'=>'.JPG', '.CR2'=>'.JPG', '.CR3'=>'.JPG', '.MOV'=>'.MOV', '.MP4'=>'.MP4', '.JPG'=>'.JPG'}

# avoid splitting photo sessions that cross midnight if a photo on the new day is taken within 3 hours of the previous one
NIGHT_BATCH_GAP=60*60*3

class FileInfo
	attr_accessor :name, :time

	def initialize(path, name)
		@name = name
		@time = File.birthtime(File.join(path, name))
	end

	def date
		@date ||= @time.strftime('%F')
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

def find_source_batches
	filenames = Dir.entries(SOURCE_PATH).select { |ent| IMPORT_EXTS.include?(File.extname(ent)) }
	files = filenames.map { |fname| FileInfo.new(SOURCE_PATH, fname) }.sort_by(&:time)
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

batches = find_source_batches
batches.each do |batch|
	batch.each do |file|
		puts "#{file.name} #{file.time.to_s}"
	end
	puts
end


