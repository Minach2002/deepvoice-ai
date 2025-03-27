import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _recordingPath;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  String _currentStatus = 'Tap the mic to start recording';
  String _detectedEmotion = '';
  String _confidence = '';
  String _currentTip = '';
  String _apiError = '';

  Future<void> _analyzeAudio() async {
    if (_recordingPath == null) return;

    setState(() {
      _isLoading = true;
      _currentStatus = 'Analyzing emotion...';
      _apiError = '';
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://9086-34-106-10-62.ngrok-free.app/predict'), // Added /predict endpoint
      );

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        _recordingPath!,
        contentType: MediaType('audio', 'wav'),
      ));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (jsonResponse['success'] == true) {
        setState(() {
          _detectedEmotion = jsonResponse['emotion'];
          _confidence = '${(double.parse(jsonResponse['confidence']) * 100).toStringAsFixed(1)}% confidence'; // Fixed decimal places
          _currentTip = jsonResponse['tip'];
          _currentStatus = 'Analysis complete';
        });
      } else {
        setState(() {
          _apiError = jsonResponse['error'] ?? 'Unknown error occurred';
          _currentStatus = 'Analysis failed';
        });
      }
    } catch (e) {
      setState(() {
        _apiError = 'Connection error: ${e.toString()}';
        _currentStatus = 'Failed to connect to server';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _currentStatus = 'Recording saved';
      });
      await _analyzeAudio();
    } else {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
        
        await _audioRecorder.start(
          RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
          path: filePath,
        );
        
        setState(() {
          _isRecording = true;
          _recordingPath = filePath;
          _detectedEmotion = '';
          _confidence = '';
          _currentTip = '';
          _apiError = '';
          _currentStatus = 'Recording... Speak now!';
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    } else if (_recordingPath != null) {
      await _audioPlayer.play(DeviceFileSource(_recordingPath!));
      setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Emotion Detection'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Indicator
              Text(
                _currentStatus,
                style: TextStyle(
                  fontSize: 18,
                  color: _isRecording ? Colors.red : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 20),

              // Recording/Playback Visual
              if (_isRecording)
                const Icon(Icons.mic, size: 80, color: Colors.red)
              else if (_recordingPath != null)
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.stop : Icons.play_arrow,
                    size: 60,
                    color: Colors.blue,
                  ),
                  onPressed: _togglePlayback,
                )
              else
                const Icon(Icons.mic_none, size: 80, color: Colors.grey),

              const SizedBox(height: 30),

              // Loading Indicator
              if (_isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Processing...'),
                  ],
                ),

              // Results Display
              if (_detectedEmotion.isNotEmpty)
                _buildResultCard(),

              // Error Display
              if (_apiError.isNotEmpty)
                _buildErrorCard(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleRecording,
        child: Icon(_isRecording ? Icons.stop : Icons.mic),
        backgroundColor: _isRecording ? Colors.red : Colors.blue,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildResultCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'DETECTED EMOTION',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _detectedEmotion.toUpperCase(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _confidence,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const Divider(height: 30),
            Text(
              'RECOMMENDED TIP',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _currentTip,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red[50],
      elevation: 4,
      margin: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 10),
            Text(
              _apiError,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _analyzeAudio,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('TRY AGAIN'),
            ),
          ],
        ),
      ),
    );
  }
}