import 'package:flutter/material.dart';
import '../models/survey_pack_model.dart';
import '../models/survey_question_model.dart';
import '../services/connectivity_service.dart';
import '../repositories/survey_repository.dart';
import '../core/app_colors.dart';

class SurveyFormWidget extends StatefulWidget {
  final SurveyPack pack;
  final String customerId;
  final VoidCallback? onCompleted;

  const SurveyFormWidget({
    Key? key,
    required this.pack,
    required this.customerId,
    this.onCompleted,
  }) : super(key: key);

  @override
  State<SurveyFormWidget> createState() => _SurveyFormWidgetState();
}

class _SurveyFormWidgetState extends State<SurveyFormWidget> {
  late Map<int, dynamic> answers = {};
  bool isSubmitting = false;
  bool isOnline = false;
  String? syncMessage;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService.instance.isConnected();
    setState(() => isOnline = online);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            _buildHeader(),
            const SizedBox(height: 16),

            // Indicador de conexión
            if (!isOnline)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.orange[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin conexión: respuestas se guardarán localmente',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Preguntas
            ...widget.pack.questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              return Column(
                children: [
                  _buildQuestion(question, index + 1),
                  if (index < widget.pack.questions.length - 1)
                    const Divider(height: 24),
                ],
              );
            }).toList(),

            const SizedBox(height: 24),

            // Botón de envío
            _buildSubmitButton(),

            // Mensaje de sincronización
            if (syncMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: syncMessage!.contains('Error')
                        ? Colors.red[50]
                        : Colors.green[50],
                    border: Border.all(
                      color: syncMessage!.contains('Error')
                          ? Colors.red[300]!
                          : Colors.green[300]!,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    syncMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: syncMessage!.contains('Error')
                          ? Colors.red[700]
                          : Colors.green[700],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.pack.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (widget.pack.description != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.pack.description!,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${widget.pack.questions.length} preguntas',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion(SurveyQuestion question, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enunciado
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  index.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                question.description,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            if (question.isRequired)
              Tooltip(
                message: 'Pregunta requerida',
                child: Text(
                  '*',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Respuesta según tipo
        _buildAnswer(question),
      ],
    );
  }

  Widget _buildAnswer(SurveyQuestion question) {
    switch (question.questionType) {
      case 'RATING':
        return _buildRatingQuestion(question);
      case 'BOOLEAN':
        return _buildBooleanQuestion(question);
      case 'MULTIPLE_CHOICE':
        return _buildMultipleChoiceQuestion(question);
      case 'TEXT':
      default:
        return _buildTextQuestion(question);
    }
  }

  Widget _buildRatingQuestion(SurveyQuestion question) {
    final selected = answers[question.id];

    return Row(
      children: List.generate(5, (i) {
        final value = i + 1;
        final isSelected = selected == value;

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => answers[question.id] = value),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryColor : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primaryColor : Colors.grey[300]!,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                  Text(
                    value == 1
                        ? 'Mal'
                        : value == 5
                            ? 'Muy bien'
                            : '',
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBooleanQuestion(SurveyQuestion question) {
    final selected = answers[question.id];

    return Row(
      children: [
        Expanded(
          child: _buildBooleanButton(
            label: 'Sí',
            value: true,
            isSelected: selected == true,
            onTap: () => setState(() => answers[question.id] = true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBooleanButton(
            label: 'No',
            value: false,
            isSelected: selected == false,
            onTap: () => setState(() => answers[question.id] = false),
          ),
        ),
      ],
    );
  }

  Widget _buildBooleanButton({
    required String label,
    required bool value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceQuestion(SurveyQuestion question) {
    final options = question.responseOptions ?? [];
    final selected = answers[question.id];

    return Column(
      children: options.map((option) {
        final isSelected = selected == option.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => setState(() => answers[question.id] = option.id),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryColor.withOpacity(0.1) : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primaryColor : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primaryColor : Colors.grey[400]!,
                      ),
                      color: isSelected ? AppColors.primaryColor : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(Icons.check,
                                color: Colors.white, size: 12),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextQuestion(SurveyQuestion question) {
    return TextField(
      onChanged: (value) => setState(() => answers[question.id] = value),
      minLines: 3,
      maxLines: 5,
      decoration: InputDecoration(
        hintText: 'Escribe tu respuesta aquí...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : _submitAnswers,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          disabledBackgroundColor: Colors.grey[400],
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                isOnline ? 'Enviar Encuesta' : 'Guardar Encuesta',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _submitAnswers() async {
    // Validar que todas las preguntas requeridas tengan respuesta
    final requiredNotAnswered = widget.pack.questions
        .where((q) => q.isRequired && !answers.containsKey(q.id))
        .toList();

    if (requiredNotAnswered.isNotEmpty) {
      _showSnackBar(
        '❌ Debes responder ${requiredNotAnswered.length} pregunta(s) requerida(s)',
        isError: true,
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      // Guardar respuestas localmente (convertir keys int a String)
      final answersAsString = answers.map((key, value) => MapEntry(key.toString(), value));
      await SurveyRepository.instance.savePendingAnswer(
        customerId: widget.customerId,
        packId: widget.pack.id,
        answers: answersAsString,
      );

      _showSnackBar('✅ Encuesta guardada localmente', isError: false);

      // Si hay conexión, intentar sincronizar
      if (isOnline) {
        await Future.delayed(const Duration(milliseconds: 500));
        _showSnackBar('📤 Encuesta enviada al servidor', isError: false);
      } else {
        _showSnackBar('⏳ Se enviará cuando vuelva la conexión', isError: false);
      }

      // Completar callback
      widget.onCompleted?.call();
    } catch (e) {
      _showSnackBar('❌ Error: $e', isError: true);
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    setState(() => syncMessage = message);

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => syncMessage = null);
      }
    });
  }
}
