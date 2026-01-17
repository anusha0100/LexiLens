import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/services/tts_service.dart';
import 'package:lexilens/services/mongodb_service.dart';
import 'package:lexilens/services/auth_service.dart';
import 'package:lexilens/models/document_model.dart';
import 'package:lexilens/models/document_tag.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  final TTSService _ttsService = TTSService();
  final MongoDBService _mongoService = MongoDBService();
  final AuthService _authService = AuthService();

  AppBloc() : super(const AppState()) {
    _initializeTTS();
    _loadUsername();

    on<NavigateToHome>((event, emit) {
      emit(state.copyWith(currentTab: AppTab.home));
    });

    on<NavigateToScan>((event, emit) {
      emit(state.copyWith(currentTab: AppTab.scan));
    });

    on<NavigateToDocs>((event, emit) {
      emit(state.copyWith(currentTab: AppTab.docs));
    });

    on<NavigateToFilter>((event, emit) {
      emit(state.copyWith(currentTab: AppTab.filter));
    });

    on<NavigateToSettings>((event, emit) {
      emit(state.copyWith(currentTab: AppTab.settings));
    });

    on<LoadDocuments>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          print('Loading documents for user: $userId');
          final mongoDocuments = await _mongoService.getUserDocuments(userId);
          
          final documents = mongoDocuments.map((doc) {
            print('Converting document: ${doc.name}');
            print('Content length: ${doc.content.length}');
            
            return Document(
              id: doc.id ?? '',
              name: doc.name,
              previewPath: 'assets/doc_preview1.png',
              uploadedDate: doc.uploadedDate,
              content: doc.content,
            );
          }).toList();

          print('Loaded ${documents.length} documents');
          emit(state.copyWith(recentDocuments: documents));
        } catch (e) {
          print('Error loading documents: $e');
          _loadMockDocuments(emit);
        }
      } else {
        print('No user ID - loading mock documents');
        _loadMockDocuments(emit);
      }
    });

    on<LoadUserProfile>((event, emit) async {
      try {
        final username = await _authService.getUsername();
        emit(state.copyWith(userName: username));
      } catch (e) {
        print('Error loading username: $e');
      }
    });

    on<OpenDocument>((event, emit) async {
      await _ttsService.stop();
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📖 OPENING DOCUMENT: ${event.documentPath}');
      
      final doc = state.recentDocuments.firstWhere(
        (d) => d.id == event.documentPath,
        orElse: () => Document(
          id: '0',
          name: 'Not found',
          previewPath: '',
          uploadedDate: DateTime.now(),
          content: '',
        ),
      );
      
      print('Document found: ${doc.name}');
      print('Content length: ${doc.content.length}');
      print('First 200 chars: ${doc.content.substring(0, doc.content.length > 200 ? 200 : doc.content.length)}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      emit(state.copyWith(
        currentDocument: doc,
        readingState: ReadingState.idle,
        currentWordIndex: 0,
      ));
    });

    on<DeleteDocument>((event, emit) async {
      if (state.currentDocument?.id == event.documentId) {
        await _ttsService.stop();
      }
      
      final updatedDocs = state.recentDocuments
          .where((doc) => doc.id != event.documentId)
          .toList();
      
      emit(state.copyWith(
        recentDocuments: updatedDocs,
        currentDocument: state.currentDocument?.id == event.documentId 
            ? null 
            : state.currentDocument,
        readingState: state.currentDocument?.id == event.documentId 
            ? ReadingState.idle 
            : state.readingState,
      ));
    });

    on<SaveDocument>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null && event.document != null) {
        try {
          final mongoDoc = DocumentModel(
            userId: userId,
            name: event.document!.name,
            content: event.document!.content,
            filePath: event.document!.previewPath,
            uploadedDate: event.document!.uploadedDate,
            tags: event.tags ?? [],
          );
          
          final savedDoc = await _mongoService.createDocument(mongoDoc);
          
          if (savedDoc != null) {
            add(LoadDocuments());
          }
        } catch (e) {
          print('Error saving document: $e');
        }
      }
    });

    on<ToggleFavoriteDocument>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          await _mongoService.updateDocument(
            event.documentId,
            {'isFavorite': event.isFavorite},
          );
        } catch (e) {
          print('Error toggling favorite: $e');
        }
      }
    });

    on<LoadDocumentTags>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          final tags = await _mongoService.getUserTags(userId);
          emit(state.copyWith(availableTags: tags));
        } catch (e) {
          print('Error loading tags: $e');
        }
      }
    });

    on<CreateDocumentTag>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          final tag = DocumentTag(
            tagName: event.tagName,
            userId: userId,
            color: event.color,
            createdAt: DateTime.now(),
          );
          
          await _mongoService.createTag(tag);
          add(LoadDocumentTags());
        } catch (e) {
          print('Error creating tag: $e');
        }
      }
    });

    on<StartTextToSpeech>((event, emit) async {
      final text = event.text ?? 
                   state.currentDocument?.content ?? 
                   "No text available to read.";
      
      print('Starting TTS');
      print('Text length: ${text.length}');
      print('First 100 chars: ${text.substring(0, text.length > 100 ? 100 : text.length)}');
      
      if (text.isEmpty || text == "No text available to read.") {
        return;
      }
      
      emit(state.copyWith(
        readingState: ReadingState.playing,
        currentWordIndex: 0,
      ));
      await _ttsService.speak(text);
    });

    on<StopTextToSpeech>((event, emit) async {
      await _ttsService.stop();
      emit(state.copyWith(
        readingState: ReadingState.idle,
        currentWordIndex: 0,
      ));
    });

    on<PauseTextToSpeech>((event, emit) async {
      await _ttsService.pause();
      emit(state.copyWith(readingState: ReadingState.paused));
    });

    on<ResumeTextToSpeech>((event, emit) async {
      await _ttsService.resume();
      emit(state.copyWith(readingState: ReadingState.playing));
    });

    on<ToggleSound>((event, emit) async {
      final newState = !state.isSoundEnabled;
      emit(state.copyWith(isSoundEnabled: newState));
      if (!newState) {
        await _ttsService.stop();
        emit(state.copyWith(readingState: ReadingState.idle));
      }
    });

    on<ToggleBookmark>((event, emit) {
      emit(state.copyWith(isBookmarked: !state.isBookmarked));
    });

    on<ToggleFont>((event, emit) {
      emit(state.copyWith(isFontEnabled: !state.isFontEnabled));
    });

    on<ToggleHighlight>((event, emit) {
      emit(state.copyWith(isHighlighted: !state.isHighlighted));
    });

    on<AdjustSpeed>((event, emit) async {
      emit(state.copyWith(readingSpeed: event.speed));
      await _ttsService.setSpeed(event.speed);
      await _saveUserSetting('reading_speed', event.speed);
    });

    on<AdjustVolume>((event, emit) async {
      emit(state.copyWith(volume: event.volume));
      await _ttsService.setVolume(event.volume);
      await _saveUserSetting('volume', event.volume);
    });

    on<AdjustPitch>((event, emit) async {
      emit(state.copyWith(pitch: event.pitch));
      await _ttsService.setPitch(event.pitch);
      await _saveUserSetting('pitch', event.pitch);
    });

    on<UpdateWordIndex>((event, emit) {
      emit(state.copyWith(currentWordIndex: event.index));
    });

    on<ChangeTextColor>((event, emit) async {
      emit(state.copyWith(selectedTextColor: event.colorIndex));
      await _saveUserSetting('text_color', event.colorIndex);
    });

    on<ChangeBackgroundColor>((event, emit) async {
      emit(state.copyWith(selectedBackgroundColor: event.colorIndex));
      await _saveUserSetting('background_color', event.colorIndex);
    });

    on<SaveFilterSettings>((event, emit) async {
      
    });

    on<LoadUserSettings>((event, emit) async {
      await _loadUserSettings(emit);
    });

    on<UploadPDF>((event, emit) {
      
    });
  }

  void _loadMockDocuments(Emitter<AppState> emit) {
    final mockDocuments = [
      Document(
        id: '1',
        name: 'Sample Document',
        previewPath: 'assets/doc_preview1.png',
        uploadedDate: DateTime.now(),
        content: "This is a sample document. You can upload your own PDFs or text files to see your content here.",
      ),
    ];
    emit(state.copyWith(recentDocuments: mockDocuments));
  }

  Future<void> _loadUsername() async {
    try {
      final username = await _authService.getUsername();
      add(LoadUserProfile());
    } catch (e) {
      print('Error loading username: $e');
    }
  }

  Future<void> _saveUserSetting(String key, dynamic value) async {
    final userId = _authService.getUserId();
    if (userId != null) {
      try {
        await _mongoService.updateSetting(userId, key, value);
      } catch (e) {
        print('Error saving setting: $e');
      }
    }
  }

  Future<void> _loadUserSettings(Emitter<AppState> emit) async {
    final userId = _authService.getUserId();
    if (userId != null) {
      try {
        final settings = await _mongoService.getAllSettings(userId);
        
        emit(state.copyWith(
          readingSpeed: settings['reading_speed']?.toDouble() ?? 0.5,
          volume: settings['volume']?.toDouble() ?? 1.0,
          pitch: settings['pitch']?.toDouble() ?? 1.0,
          selectedTextColor: settings['text_color']?.toInt() ?? 0,
          selectedBackgroundColor: settings['background_color']?.toInt() ?? 0,
          userName: settings['user_name']?.toString() ?? await _authService.getUsername(),
        ));
      } catch (e) {
        print('Error loading settings: $e');
      }
    }
  }

  Future<void> _initializeTTS() async {
    await _ttsService.initialize();
    
    _ttsService.onStart = () {
      add(UpdateReadingState(ReadingState.playing));
    };

    _ttsService.onComplete = () {
      add(UpdateReadingState(ReadingState.idle));
      add(UpdateWordIndex(0));
    };

    _ttsService.onWordHighlight = (index) {
      add(UpdateWordIndex(index));
    };
  }

  @override
  Future<void> close() {
    _ttsService.dispose();
    return super.close();
  }
}