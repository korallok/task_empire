import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/calendar/bloc/calendar_bloc.dart';
import 'package:task_empire/features/calendar/data/task_repository.dart';
import 'package:task_empire/features/city/bloc/city_bloc.dart';
import 'package:task_empire/features/city/data/city_repository.dart';
import 'package:task_empire/home_shell.dart';

class CalendarStrategyApp extends StatelessWidget {
  const CalendarStrategyApp({required this.supabase, super.key});

  final SupabaseClient supabase;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TaskRepository>(
          create: (_) => SupabaseTaskRepository(supabase),
        ),
        RepositoryProvider<CityRepository>(
          create: (_) => SupabaseCityRepository(supabase),
        ),
      ],
      child: const TaskEmpireView(),
    );
  }
}

class TaskEmpireView extends StatelessWidget {
  const TaskEmpireView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CalendarBloc>(
          create: (context) =>
              CalendarBloc(repository: context.read<TaskRepository>())
                ..add(const CalendarStarted()),
        ),
        BlocProvider<CityBloc>(
          create: (context) =>
              CityBloc(repository: context.read<CityRepository>()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ru'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ru')],
        onGenerateTitle: (_) => 'Task Empire',
        theme: AppTheme.light(),
        home: const HomeShell(),
      ),
    );
  }
}
