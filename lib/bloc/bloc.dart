import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/events.dart';
import 'package:lexilens/bloc/states.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(
    const OnboardingState(
      currentPage: 0, 
      totalPages: 5,
    ),
  ) {
    on<NextPage>((event, emit) {
      if (state.currentPage < state.totalPages - 1) {
        emit(
          state.copyWith(
            currentPage: state.currentPage + 1,
          ),
        );
      }
    });

    on<PreviousPage>((event, emit) {
      if (state.currentPage > 0) {
        emit(
          state.copyWith(
            currentPage: state.currentPage - 1,
          ),
        );
      }
    });

    on<GoToPage>((event, emit) {
      if (event.pageIndex >= 0 && event.pageIndex < state.totalPages) {
        emit(
          state.copyWith(
            currentPage: event.pageIndex,
          ),
        );
      }
    });

    on<CompleteOnboarding>((event, emit) {
      // Main app navigation
    });
  }
}