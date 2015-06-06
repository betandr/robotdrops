require 'json'

@api_key = 'O098HQYYTKMBTOYWK'

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

def upload_track(filename)
    p "uploading #{filename}"
    basename = track_basename(filename)

    tmpfile = "/tmp/#{basename}.json"

    p "storing as #{tmpfile}"

    system "curl -F \"api_key=#{@api_key}\" -F \"filetype=mp3\" -F \"track=@#{filename}\" \"http://developer.echonest.com/api/v4/track/upload\" > #{tmpfile}"

    file = File.open(tmpfile, "rb")
    analysis = file.read
    json = JSON.parse(analysis)

    id = json['response']['track']['id']

    download_audio_summary(id, basename)

    basename
end

def download_audio_summary(id, basename)
    tmpfile = "/tmp/#{id}.json"

    system "curl -X GET 'http://developer.echonest.com/api/v4/track/profile?api_key=#{@api_key}&format=json&id=#{id}&bucket=audio_summary' > #{tmpfile}"

    file = File.open(tmpfile, "rb")
    analysis = file.read
    json = JSON.parse(analysis)

    analysis_url = json['response']['track']['audio_summary']['analysis_url']

    download_analysis(analysis_url, basename)
end

def download_analysis(url, basename)
    system "curl -vX GET '#{url}' > ./analysis/#{basename}.json"
end

def build_track(json_file)
    p "building track from #{json_file}"

    file = File.open(json_file, "rb")
    analysis = file.read

    json = JSON.parse(analysis)
    track = Track.new

    track.title = json['meta']['title']
    track.artist = json['meta']['artist']

    track.tempo = json['track']['tempo'].to_i
    track.bars = json['bars']

    file.close

    track
end

def load_drum_tracks(bpm)
    p "loading drum tracks for #{bpm} bpm"

    kick_sample = "./samples/kick.wav"
    if !File.exists?(kick_sample) then
        system "curl -X GET 'http://donk.andr.io/kick?bpm=#{bpm}' > #{kick_sample}"
    end

    clap_sample = "./samples/clap.wav"
    if !File.exists?(clap_sample) then
        system "curl -X GET 'http://donk.andr.io/clap?bpm=#{bpm}' > #{clap_sample}"
    end

    donk_sample = "./samples/donk.wav"
    if !File.exists?(donk_sample) then
        system "curl -X GET 'http://donk.andr.io/donk?bpm=#{bpm}' > #{donk_sample}"
    end

    p "adding donk"
    system "cp #{donk_sample} ./clips/1_7.wav"

    p "pre-mixing drum track"
    system "sox -m #{kick_sample} #{clap_sample} ./clips/0_7.wav"
end

def load_samples
    p "loading samples"
    system "cp ./samples/sample1.wav ./clips/5_7.wav"
    system "cp ./samples/sample2.wav ./clips/6_7.wav"
    system "cp ./samples/sample3.wav ./clips/7_7.wav"
end

def make_working_clip(file, outfile)
    p "creating wave"
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

    max_number_of_clips = 56
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
        p "already have that data so not going to bother Echonest"
        id = basename
    else
        id = upload_track(track_file)
    end

elsif (mode == "offline")
    id = ARGV[2]
else
    p "unknown mode #{mode}"
end

p "building track for id #{id}"

track = build_track("analysis/#{id}.json")

system 'rm ./clips/*.wav'

load_drum_tracks(track.tempo)
load_samples

outfile = "./clips/audio.wav"
make_working_clip(track_file, outfile)
make_clips(track, outfile)
