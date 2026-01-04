import 'package:equatable/equatable.dart';
import 'package:lexilens/bloc/app_states.dart';

abstract class AppEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

// Navigation Events
class NavigateToHome extends AppEvent {}
class NavigateToScan extends AppEvent {}
class NavigateToDocs extends AppEvent {}
class NavigateToFilter extends AppEvent {}
class NavigateToSettings extends AppEvent {}

// Document Events
class LoadDocuments extends AppEvent {}

class OpenDocument extends AppEvent {
  final String documentPath;
  OpenDocument(this.documentPath);
  
  @override
  List<Object?> get props => [documentPath];
}

class DeleteDocument extends AppEvent {
  final String documentId;
  DeleteDocument(this.documentId);
  
  @override
  List<Object?> get props => [documentId];
}

// Reading/TTS Events
class StartTextToSpeech extends AppEvent {
  final String? text;
  StartTextToSpeech({this.text});
  
  @override
  List<Object?> get props => [text];
}

class StopTextToSpeech extends AppEvent {}

class PauseTextToSpeech extends AppEvent {}

class ResumeTextToSpeech extends AppEvent {}

class UpdateReadingState extends AppEvent {
  final ReadingState state;
  UpdateReadingState(this.state);
  
  @override
  List<Object?> get props => [state];
}

class UpdateWordIndex extends AppEvent {
  final int index;
  UpdateWordIndex(this.index);
  
  @override
  List<Object?> get props => [index];
}

// Control Events
class ToggleSound extends AppEvent {}
class ToggleBookmark extends AppEvent {}
class ToggleFont extends AppEvent {}
class ToggleHighlight extends AppEvent {}

// Audio Adjustment Events
class AdjustSpeed extends AppEvent {
  final double speed;
  AdjustSpeed(this.speed);
  
  @override
  List<Object?> get props => [speed];
}

class AdjustVolume extends AppEvent {
  final double volume;
  AdjustVolume(this.volume);
  
  @override
  List<Object?> get props => [volume];
}

class AdjustPitch extends AppEvent {
  final double pitch;
  AdjustPitch(this.pitch);
  
  @override
  List<Object?> get props => [pitch];
}

// Filter Events
class ChangeTextColor extends AppEvent {
  final int colorIndex;
  ChangeTextColor(this.colorIndex);
  
  @override
  List<Object?> get props => [colorIndex];
}

class ChangeBackgroundColor extends AppEvent {
  final int colorIndex;
  ChangeBackgroundColor(this.colorIndex);
  
  @override
  List<Object?> get props => [colorIndex];
}

class SaveFilterSettings extends AppEvent {}

// Upload Events
class UploadPDF extends AppEvent {}