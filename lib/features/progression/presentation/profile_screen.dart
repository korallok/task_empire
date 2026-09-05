import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/progression/bloc/progression_bloc.dart';
import 'package:task_empire/features/progression/domain/progression_profile.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({this.isActive = true, super.key});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProgressionBloc, ProgressionState>(
      listenWhen: (previous, current) =>
          isActive &&
          current is ProgressionDisplay &&
          current.errorMessage != null,
      listener: (context, state) {
        if (state case ProgressionDisplay(:final errorMessage?)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
        }
      },
      builder: (context, state) {
        final bottomInset = MediaQuery.sizeOf(context).width < 900
            ? 92.0
            : 20.0;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: switch (state) {
              ProgressionFailure(:final message) => _ProfileFailure(
                message: message,
              ),
              _ when state.profile == null => const Center(
                child: CircularProgressIndicator(),
              ),
              _ => _ProfileBody(
                state: state,
                profile: state.profile!,
                bottomInset: bottomInset,
              ),
            },
          ),
        );
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.state,
    required this.profile,
    required this.bottomInset,
  });

  final ProgressionState state;
  final ProgressionProfile profile;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileHero(profile: profile),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 720;
                          final stats = _StatsCard(profile: profile);
                          final account = _AccountCard(profile: profile);
                          if (!wide) {
                            return Column(
                              children: [
                                stats,
                                const SizedBox(height: 14),
                                account,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: stats),
                              const SizedBox(width: 14),
                              Expanded(child: account),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      const _SettingsCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (state is ProgressionLoading)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<ProgressionBloc>()
      ..add(const ProgressionRefreshRequested());
    await bloc.stream.firstWhere(
      (next) => next is ProgressionDisplay || next is ProgressionFailure,
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final ProgressionProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x32153B33),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final identity = Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  gradient: AppColors.goldGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${profile.level}',
                    style: const TextStyle(
                      color: AppColors.forest950,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ПРАВИТЕЛЬ ГОРОДА',
                      style: TextStyle(
                        color: AppColors.gold400,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${profile.level} уровень',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      profile.isGuest ? 'Гостевой профиль' : 'Профиль сохранён',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          );
          final treasury = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: AppColors.gold400,
                ),
                const SizedBox(width: 8),
                Text(
                  '${profile.gold}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'золота',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                identity,
                const SizedBox(height: 16),
                treasury,
              ] else
                Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 18),
                    treasury,
                  ],
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    '${profile.xpIntoLevel} XP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${profile.xpForNextLevel} XP до нового уровня',
                      maxLines: 2,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: profile.levelProgress,
                  minHeight: 9,
                  color: AppColors.gold400,
                  backgroundColor: Colors.white12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.profile});

  final ProgressionProfile profile;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Прогресс',
      icon: Icons.auto_graph_rounded,
      child: Column(
        children: [
          _StatRow(
            icon: Icons.bolt_rounded,
            label: 'Всего опыта',
            value: '${profile.xp} XP',
          ),
          const Divider(height: 24),
          _StatRow(
            icon: Icons.task_alt_rounded,
            label: 'Выполнено задач',
            value: '${profile.completedTasks}',
          ),
          const Divider(height: 24),
          _StatRow(
            icon: Icons.local_fire_department_outlined,
            label: 'Текущая серия',
            value: '${profile.streak} дн.',
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.profile});

  final ProgressionProfile profile;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Аккаунт',
      icon: Icons.shield_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            profile.isGuest
                ? 'Прогресс хранится в гостевом профиле этого устройства.'
                : 'Ваш прогресс связан с постоянным аккаунтом.',
            style: const TextStyle(color: AppColors.mutedInk, height: 1.4),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.link_rounded),
            label: Text(
              profile.isGuest
                  ? 'Сохранение аккаунта — следующий этап'
                  : 'Аккаунт сохранён',
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      title: 'Настройки',
      icon: Icons.tune_rounded,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.language_rounded),
            title: Text('Язык'),
            trailing: Text('Русский'),
          ),
          Divider(height: 1),
          ListTile(
            enabled: false,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.notifications_outlined),
            title: Text('Уведомления'),
            subtitle: Text('Будут добавлены после базового релиза'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x140E2924)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.forest700),
              const SizedBox(width: 9),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold600),
        const SizedBox(width: 11),
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.forest900,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProfileFailure extends StatelessWidget {
  const _ProfileFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 54,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.read<ProgressionBloc>().add(
                const ProgressionStarted(),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
