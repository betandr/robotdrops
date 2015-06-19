require 'json'
require 'yaml'

@api_key = ''

@grid_positions = [
    "0_0", "1_0", "2_0", "3_0", "4_0", "5_0", "6_0", "7_0",
    "0_1", "1_1", "2_1", "3_1", "4_1", "5_1", "6_1", "7_1",
    "0_2", "1_2", "2_2", "3_2", "4_2", "5_2", "6_2", "7_2",
    "0_3", "1_3", "2_3", "3_3", "4_3", "5_3", "6_3", "7_3",
    "0_4", "1_4", "2_4", "3_4", "4_4", "5_4", "6_4", "7_4",
    "0_5", "1_5", "2_5", "3_5", "4_5", "5_5", "6_5", "7_5",
    "0_6", "1_6", "2_6", "3_6", "4_6", "5_6", "6_6", "7_6",
    "0_7", "1_7", "2_7", "3_7", "4_7", "5_7", "6_7", "7_7",
]

class Track
    attr_accessor :title
    attr_accessor :artist
    attr_accessor :tempo
    attr_accessor :bars
end

def download_track_analysis(filename, tmpfile)
    system "curl -F \"api_key=#{@api_key}\" -F \"filetype=mp3\" -F \"track=@#{filename}\" \"http://developer.echonest.com/api/v4/track/upload\" > #{tmpfile}"
end

def upload_track(filename)
    p "uploading #{filename}"
    basename = track_basename(filename)

    tmpfile = "/tmp/#{basename}.json"

    p "storing as #{tmpfile}"

    download_track_analysis(filename, tmpfile)
    file = File.open(tmpfile, "rb")
    analysis = file.read

    json = JSON.parse(analysis)

    id = json['response']['track']['id']

    download_audio_summary(id, basename)

    basename
end

def download_audio_summary(id, basename)
    tmpfile = "/tmp/#{id}.json"

    system "curl --silent -X GET 'http://developer.echonest.com/api/v4/track/profile?api_key=#{@api_key}&format=json&id=#{id}&bucket=audio_summary' > #{tmpfile}"

    download_analysis(tmpfile, basename)
end

def download_analysis(filename, basename)
    file = File.open(filename, "rb")
    analysis = file.read
    json = JSON.parse(analysis)

    p "getting analysis url from #{filename}"

    analysis_url = json['response']['track']['audio_summary']['analysis_url']

    p "requesting analysis..."
    system "curl --silent -X GET '#{analysis_url}' > ./analysis/#{basename}.json"
    p "analysis saved to analysis/#{basename}.json"
end

def build_track(id, basename)

    json_file = "analysis/#{basename}.json"

    p "building track for #{id} from #{json_file}"

    json = "{}"

    loopcount = 2

    while(true) do

        file = File.open(json_file, "rb")
        analysis = file.read

        if (analysis.include? "NoSuchKey") then
            p "waiting for analysis from Echonest..."
            sleep 3

            p "making request #{loopcount} to Echonest"
            loopcount += 1

            tmpfile = File.open("/tmp/#{id}.json", "rb")
            track_id = JSON.parse(tmpfile.read)['response']['track']['id']

            system "rm #{json_file}"
            download_analysis("/tmp/#{track_id}.json", basename)
        else
            p "analysis loaded"
            json = JSON.parse(analysis)
            break
        end
    end

    track = Track.new

    track.title = json['meta']['title']
    track.artist = json['meta']['artist']

    track.tempo = json['track']['tempo'].to_i
    track.bars = json['bars']

    file.close

    track
end

def make_working_clip(file, outfile)
    p "creating working wave clip"
    system "sox #{file} ./clips/audio.wav"
end

def track_basename(filename)
    File.basename(filename).gsub('.', '_')
end

# Please don't hate me for this! L:/
def translate_index_to_grid_position(index)
    @grid_positions[index]
end

def make_clips(track, outfile)
    p "making clips from #{track.title} by #{track.artist}"

    max_number_of_clips = 64
    clip_count = 0
    track.bars.each do |bar|
        confidence = bar['confidence']
        if (confidence > 0.50)

            if (clip_count < (max_number_of_clips + 1))
                start_time = bar['start']
                end_time = bar['duration'] + bar['start']

                system "sox #{outfile} ./clips/#{
                    translate_index_to_grid_position(clip_count)
                }.wav trim #{start_time} =#{end_time}"
            end

            clip_count += 1
        end
    end

    if (clip_count > (max_number_of_clips + 1))
        p "found #{clip_count} clips but can only use #{max_number_of_clips}"
    else
        p "found #{clip_count} clips"
    end
end

config = YAML::load_file("config/config.yaml")
@api_key = config['api_key']

if (ARGV.length < 2) then
    p "usage bundle exec ruby analyzer.rb <filename> <live|offline> "
    exit(1)
end

track_file = ARGV[0]
mode = ARGV[1]
id = ""

p "analyzing #{track_file} in mode [#{mode}]"

if (mode == "live")
    basename = track_basename(track_file)

    file = "analysis/#{basename}.json"

    p "looking for #{file}"
    if File.exists?(file) then
        p "already have that data so not requesting from Echonest"
        id = basename
    else
        id = upload_track(track_file)
    end

elsif (mode == "offline")
    id = ARGV[2]
else
    p "unknown mode #{mode}"
end

system 'rm ./clips/*.wav'

p "requesting id #{id}"
track = build_track(id, basename)

outfile = "./clips/audio.wav"
make_working_clip(track_file, outfile)
make_clips(track, outfile)
