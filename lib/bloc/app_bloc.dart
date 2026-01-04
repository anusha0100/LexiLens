import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/services/tts_service.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  final TTSService _ttsService = TTSService();

  AppBloc() : super(const AppState()) {
    _initializeTTS();

    on<NavigateToHome>((event, emit) {
      emit(
        state.copyWith(
          currentTab: AppTab.home,
        ),
      );
    });

    on<NavigateToScan>((event, emit) {
      emit(
        state.copyWith(
          currentTab: AppTab.scan,
        ),
      );
    });

    on<NavigateToDocs>((event, emit) {
      emit(
        state.copyWith(
          currentTab: AppTab.docs,
        ),
      );
    });

    on<NavigateToFilter>((event, emit) {
      emit(
        state.copyWith(
          currentTab: AppTab.filter,
        ),
      );
    });

    on<NavigateToSettings>((event, emit) {
      emit(
        state.copyWith(
          currentTab: AppTab.settings,
        ),
      );
    });

    on<LoadDocuments>((event, emit) {
      final mockDocuments = [
        Document(
          id: '1',
          name: 'Chapter1.docx',
          previewPath: 'assets/doc_preview1.png',
          uploadedDate: DateTime.now().subtract(
            const Duration(
              days: 1,
            ),
          ),
          content: "I SWORE IT WASN'T STEALING—reading until we outgrew it.",
        ),
        Document(
          id: '2',
          name: 'English.Docx',
          previewPath: 'assets/doc_preview2.png',
          uploadedDate: DateTime.now().subtract(
            const Duration(
              days: 7,
            ),
          ),
          content: "The quick brown fox jumps over the lazy dog.",
        ),
        Document(
          id: '3',
          name: 'Mathematics.pdf',
          previewPath: 'assets/doc_preview3.png',
          uploadedDate: DateTime.now().subtract(
            const Duration(
              days: 10,
            ),
          ),
          content: "Mathematics is the study of patterns and structures.",
        ),
        Document(
          id: '4',
          name: 'History.pdf',
          previewPath: 'assets/doc_preview4.png',
          uploadedDate: DateTime.now().subtract(
            const Duration(
              days: 14,
            ),
          ),
          content: "History teaches us valuable lessons from the past.",
        ),
      ];
      emit(state.copyWith(recentDocuments: mockDocuments));
    });

    on<OpenDocument>((event, emit) async {
      await _ttsService.stop();
      final doc = state.recentDocuments.firstWhere(
        (d) => d.id == event.documentPath,
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

    on<StartTextToSpeech>((event, emit) async {
      final text = event.text ?? 
                   state.currentDocument?.content ?? 
                   "No text available to read.";
      if (text.isEmpty || text == "No text available to read.") {
        return;
      }
      emit(
        state.copyWith(
        readingState: ReadingState.playing,
        currentWordIndex: 0,
      ));
      await _ttsService.speak(text);
    });
    on<StopTextToSpeech>((event, emit) async {
      await _ttsService.stop();
      emit(
        state.copyWith(
        readingState: ReadingState.idle,
        currentWordIndex: 0,
      ));
    });

    on<PauseTextToSpeech>((event, emit) async {
      await _ttsService.pause();
      emit(
        state.copyWith(
          readingState: ReadingState.paused,
        ),
      );
    });

    on<ResumeTextToSpeech>((event, emit) async {
      await _ttsService.resume();
      emit(
        state.copyWith(
          readingState: ReadingState.playing,
        ),
      );
    });

    on<ToggleSound>((event, emit) async {
      final newState = !state.isSoundEnabled;
      emit(
        state.copyWith(
          isSoundEnabled: newState,
        ),
      );
      if (!newState) {
        await _ttsService.stop();
        emit(
          state.copyWith(
            readingState: ReadingState.idle,
          ),
        );
      }
    });
    on<ToggleBookmark>((event, emit) {
      emit(
        state.copyWith(
          isBookmarked: !state.isBookmarked,
        ),
      );
    });
    on<ToggleFont>((event, emit) {
      emit(
        state.copyWith(
          isFontEnabled: !state.isFontEnabled,
        ),
      );
    });
    on<ToggleHighlight>((event, emit) {
      emit(
        state.copyWith(
          isHighlighted: !state.isHighlighted,
        ),
      );
    });
    on<AdjustSpeed>((event, emit) async {
      emit(
        state.copyWith(
          readingSpeed: event.speed,
        ),
      );
      await _ttsService.setSpeed(event.speed);
    });
    on<AdjustVolume>((event, emit) async {
      emit(
        state.copyWith(
          volume: event.volume,
        ),
      );
      await _ttsService.setVolume(event.volume);
    });

    on<AdjustPitch>((event, emit) async {
      emit(
        state.copyWith(
          pitch: event.pitch,
        ),
      );
      await _ttsService.setPitch(event.pitch);
    });

    on<UpdateWordIndex>((event, emit) {
      emit(
        state.copyWith(
          currentWordIndex: event.index,
        ),
      );
    });

    on<ChangeTextColor>((event, emit) {
      emit(
        state.copyWith(
          selectedTextColor: event.colorIndex,
        ),
      );
    });

    on<ChangeBackgroundColor>((event, emit) {
      emit(
        state.copyWith(
          selectedBackgroundColor: event.colorIndex,
        ),
      );
    });

    on<SaveFilterSettings>((event, emit) {
      // TODO: Save settings to storage
    });

    on<UploadPDF>((event, emit) {
      // TODO: Implement file picker and upload
    });
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