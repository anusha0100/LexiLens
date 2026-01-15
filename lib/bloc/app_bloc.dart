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
          // Load documents from MongoDB
          final documents = await _mongoService.getUserDocuments(userId);
          // Convert DocumentModel to Document
          final recentDocs = documents.map((doc) => Document(
            id: doc.id ?? '',
            name: doc.name,
            previewPath: 'assets/doc_preview1.png',
            uploadedDate: doc.uploadedDate,
            content: doc.content,
          )).toList();

          emit(state.copyWith(recentDocuments: recentDocs));
        } catch (e) {
          print('Error loading documents: $e');
          // Fallback to mock data if MongoDB fails
          _loadMockDocuments(emit);
        }
      } else {
        // Load mock documents if not logged in
        _loadMockDocuments(emit);
      }
    });

    on<OpenDocument>((event, emit) async {
      await _ttsService.stop();
      
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          // Try to get document from MongoDB
          final mongoDoc = await _mongoService.getDocument(event.documentPath);
          if (mongoDoc != null) {
            // Update last read date
            await _mongoService.updateDocument(
              event.documentPath,
              {'last_read_date': DateTime.now().toIso8601String()},
            );
            
            final doc = Document(
              id: mongoDoc.id ?? '',
              name: mongoDoc.name,
              previewPath: 'assets/doc_preview1.png',
              uploadedDate: mongoDoc.uploadedDate,
              content: mongoDoc.content,
            );
            
            emit(state.copyWith(
              currentDocument: doc,
              readingState: ReadingState.idle,
              currentWordIndex: 0,
            ));
            return;
          }
        } catch (e) {
          print('Error opening document from MongoDB: $e');
        }
      }
      // Fallback to local documents
      final doc = state.recentDocuments.firstWhere(
        (d) => d.id == event.documentPath,
        orElse: () => state.recentDocuments.first,
      );
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
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          // Delete from MongoDB
          await _mongoService.deleteDocument(event.documentId);
        } catch (e) {
          print('Error deleting document from MongoDB: $e');
        }
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
            uploadedDate: event.document!.uploadedDate,
            tags: event.tags ?? [],
          );
          final savedDoc = await _mongoService.createDocument(mongoDoc);
          
          if (savedDoc != null) {
            // Reload documents
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
            {'is_favorite': event.isFavorite},
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
      
      // Save to MongoDB settings
      await _saveUserSetting('reading_speed', event.speed);
    });

    on<AdjustVolume>((event, emit) async {
      emit(state.copyWith(volume: event.volume));
      await _ttsService.setVolume(event.volume);
      // Save to MongoDB settings
      await _saveUserSetting('volume', event.volume);
    });

    on<AdjustPitch>((event, emit) async {
      emit(state.copyWith(pitch: event.pitch));
      await _ttsService.setPitch(event.pitch);
      // Save to MongoDB settings
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
        name: 'Chapter1.docx',
        previewPath: 'assets/doc_preview1.png',
        uploadedDate: DateTime.now().subtract(const Duration(days: 1)),
        content: "I SWORE IT WASN'T STEALING—reading until we outgrew it.",
      ),
      Document(
        id: '2',
        name: 'English.Docx',
        previewPath: 'assets/doc_preview2.png',
        uploadedDate: DateTime.now().subtract(const Duration(days: 7)),
        content: "The quick brown fox jumps over the lazy dog.",
      ),
    ];
    emit(state.copyWith(recentDocuments: mockDocuments));
  }

  Future<void> _saveUserSetting(String key, dynamic value) async {
    final userId = _authService.getUserId();
    if (userId != null) {
      try {
        await _mongoService.updateSetting('${userId}_$key', value);
      } catch (e) {
        print('Error saving setting: $e');
      }
    }
  }

  Future<void> _loadUserSettings(Emitter<AppState> emit) async {
    final userId = _authService.getUserId();
    if (userId != null) {
      try {
        final settings = await _mongoService.getAllSettings();
        
        emit(state.copyWith(
          readingSpeed: settings['${userId}_reading_speed'] ?? 0.5,
          volume: settings['${userId}_volume'] ?? 1.0,
          pitch: settings['${userId}_pitch'] ?? 1.0,
          selectedTextColor: settings['${userId}_text_color'] ?? 0,
          selectedBackgroundColor: settings['${userId}_background_color'] ?? 0,
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