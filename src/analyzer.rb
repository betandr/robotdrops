require 'json'

@api_key = 'O098HQYYTKMBTOYWK'

class Track
    attr_accessor :tempo
    attr_accessor :bars
end

def upload_track(filename)
    # system "curl -F 'api_key=#{@api_key}" -F \"filetype=mp3\" -F \"track=@#{filename}\" \"http://developer.echonest.com/api/v4/track/upload\"'"
end

def download_analysis(id)
    # system 'curl -vX GET "http://developer.echonest.com/api/v4/track/profile?api_key=#{@api_key}&format=json&id=#{id}&bucket=audio_summary > ./analysis/#{id}.json"'
end

def build_track(json_file)
    file = File.open(json_file, "rb")
    analysis = file.read

    json = JSON.parse(analysis)
    track = Track.new
    track.tempo = json['track']['tempo'].to_i
    track.bars = json['bars']

    file.close

    track
end

def load_donks(bpm)
    p "loading drum tracks for #{bpm} bpm"
    system "curl -X GET 'http://donk.andr.io/kick?bpm=#{bpm}' > ./clips/0_7a.wav"
    system "curl -X GET 'http://donk.andr.io/clap?bpm=#{bpm}' > ./clips/1_7a.wav"
    system "curl -X GET 'http://donk.andr.io/donk?bpm=#{bpm}' > ./clips/2_7a.wav"

    p "boosting audio"
    system "sox -v 2.0 ./clips/0_7a.wav ./clips/0_7.wav"
    system "sox -v 2.0 ./clips/1_7a.wav ./clips/1_7.wav"
    system "sox -v 2.0 ./clips/2_7a.wav ./clips/2_7.wav"

    p "pre-mixing drum tracks"
    system "sox -m ./clips/0_7.wav ./clips/1_7.wav ./clips/3_7.wav"
    system "sox -m ./clips/0_7.wav ./clips/1_7.wav ./clips/2_7.wav ./clips/4_7.wav"
end

def load_samples
    p "loading samples"
    system "cp ./samples/sample1.wav ./clips/5_7.wav"
    system "cp ./samples/sample2.wav ./clips/6_7.wav"
    system "cp ./samples/sample3.wav ./clips/7_7.wav"
end

track_file = ARGV[0]

if (ARGV.length < 1) then
    p "filename missing..."
    exit(1)
end

p "analyzing #{track_file}"
# upload_track(ARGV[0])
id = 'TRPYPQX14DC8E93944'
# download_analysis("TRPYPQX14DC8E93944")

track = build_track("analysis/#{id}.json")

system 'rm ./clips/*.wav'

load_donks(track.tempo)
load_samples

#
# clip_count = 0
# track.bars.each do |bar|
#     confidence = bar['confidence']
#     if (confidence > 0.65)
#         p "sox #{track_file} ./clips/#{clip_count}.wav trim #{bar['start']} #{bar['duration']}"
#         clip_count += 1
#     end
# end
