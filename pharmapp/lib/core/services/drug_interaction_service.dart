import 'package:flutter/material.dart';

enum WarningSeverity { allergy, major, moderate, minor }

class DrugWarning {
  final WarningSeverity severity;
  final String message;
  const DrugWarning({required this.severity, required this.message});
}

class DrugInteractionService {
  static List<DrugWarning> checkInteractions(
    String newDrug,
    List<String> currentMedications,
    List<String> allergies,
  ) {
    final drug = newDrug.toLowerCase().trim();
    final warnings = <DrugWarning>[];

    for (final allergy in allergies) {
      final a = allergy.toLowerCase().trim();
      if (_isPenicillinAllergy(a) && _isPenicillinDrug(drug)) {
        warnings.add(DrugWarning(
          severity: WarningSeverity.allergy,
          message: 'Patient is allergic to penicillin. $newDrug may cause a severe allergic reaction.',
        ));
      } else if (_isSulfaAllergy(a) && _isSulfaDrug(drug)) {
        warnings.add(DrugWarning(
          severity: WarningSeverity.allergy,
          message: 'Patient has sulfa allergy. $newDrug contains a sulfonamide compound.',
        ));
      } else if (_isNsaidAllergy(a) && _isNsaidDrug(drug)) {
        warnings.add(DrugWarning(
          severity: WarningSeverity.allergy,
          message: 'Patient is allergic to NSAIDs/aspirin. $newDrug is an NSAID.',
        ));
      } else if (_isCephalosporinAllergy(a) && _isCephalosporinDrug(drug)) {
        warnings.add(DrugWarning(
          severity: WarningSeverity.allergy,
          message: 'Patient is allergic to cephalosporins. $newDrug is a cephalosporin antibiotic.',
        ));
      } else if (_isErythromycinAllergy(a) && _isMacrolideDrug(drug)) {
        warnings.add(DrugWarning(
          severity: WarningSeverity.allergy,
          message: 'Patient is allergic to macrolide antibiotics. $newDrug is a macrolide.',
        ));
      } else if (_isCodeineAllergy(a) && _isOpioidDrug(drug)) {
        warnings.add(DrugWarning(
          severity: WarningSeverity.allergy,
          message: 'Patient is allergic to opioids/codeine. $newDrug is an opioid.',
        ));
      } else if (_isMetronidazoleAllergy(a) && drug.contains('metronidazole')) {
        warnings.add(const DrugWarning(
          severity: WarningSeverity.allergy,
          message: 'Patient is allergic to metronidazole (Flagyl).',
        ));
      } else if (_isStatinAllergy(a) && _isStatinDrug(drug)) {
        warnings.add(DrugWarning(
          severity: WarningSeverity.allergy,
          message: 'Patient has reported statin intolerance. $newDrug is a statin.',
        ));
      }
    }

    for (final med in currentMedications) {
      final m = med.toLowerCase().trim();
      _checkDrugInteraction(drug, m, newDrug, med, warnings);
    }

    return warnings;
  }

  static void _checkDrugInteraction(
    String drug,
    String existing,
    String drugDisplay,
    String existingDisplay,
    List<DrugWarning> warnings,
  ) {
    if (_isWarfarin(existing) && _isNsaidDrug(drug)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.major,
        message: '$drugDisplay + $existingDisplay: Increased bleeding risk. NSAIDs potentiate anticoagulant effect.',
      ));
    }

    if (_isWarfarin(existing) && _isAntibioticAffectingWarfarin(drug)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.major,
        message: '$drugDisplay + $existingDisplay: Antibiotic may enhance anticoagulant effect, raising INR.',
      ));
    }

    if (_isMetformin(existing) && _isContrastedOrAlcohol(drug)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.moderate,
        message: '$drugDisplay combined with metformin may increase risk of lactic acidosis.',
      ));
    }

    if (_isMaoi(existing) && _isSsriOrTriptan(drug)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.major,
        message: '$drugDisplay + $existingDisplay: Risk of serotonin syndrome. Potentially life-threatening.',
      ));
    }

    if (_isSsri(existing) && _isSsriOrTriptan(drug)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.moderate,
        message: '$drugDisplay + $existingDisplay: Combining serotonergic agents may increase serotonin syndrome risk.',
      ));
    }

    if (_isAceInhibitor(existing) && _isNsaidDrug(drug)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.moderate,
        message: '$drugDisplay may reduce the antihypertensive effect of $existingDisplay and worsen kidney function.',
      ));
    }

    if (_isDigoxin(existing) && _isMacrolideDrug(drug)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.major,
        message: '$drugDisplay may increase digoxin levels, risking toxicity (nausea, arrhythmias).',
      ));
    }

    if (_isStatinDrug(existing) && _isCyp3a4Inhibitor(drug)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.major,
        message: '$drugDisplay inhibits CYP3A4 and may increase $existingDisplay levels, raising myopathy risk.',
      ));
    }

    if (_isLithium(existing) && _isNsaidDrug(drug)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.major,
        message: '$drugDisplay may reduce lithium excretion, increasing risk of lithium toxicity.',
      ));
    }

    if (_isAnticoagulant(existing) && _isAntiplatelet(drug)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.moderate,
        message: '$drugDisplay + $existingDisplay: Additive bleeding risk when combining anticoagulant and antiplatelet therapy.',
      ));
    }

    if (_isTetracycline(drug) && _isCalciumOrAntacid(existing)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.minor,
        message: '$existingDisplay reduces absorption of $drugDisplay. Administer at least 2 hours apart.',
      ));
    }

    if (_isQuinolone(drug) && _isCalciumOrAntacid(existing)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.moderate,
        message: '$existingDisplay may chelate $drugDisplay and reduce its absorption.',
      ));
    }

    if (_isBetaBlocker(existing) && _isCalciumChannelBlocker(drug)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.moderate,
        message: '$drugDisplay + $existingDisplay: Combination may cause excessive bradycardia or heart block.',
      ));
    }

    if (_isSildenafil(drug) && _isNitrate(existing)) {
      warnings.add(DrugWarning(
        severity: WarningSeverity.major,
        message: '$drugDisplay + $existingDisplay: Severe hypotension risk. Combination is contraindicated.',
      ));
    }
  }

  static bool _isPenicillinAllergy(String a) =>
      a.contains('penicillin') || a.contains('amoxicillin') || a.contains('ampicillin');

  static bool _isPenicillinDrug(String d) =>
      d.contains('penicillin') || d.contains('amoxicillin') || d.contains('ampicillin') ||
      d.contains('flucloxacillin') || d.contains('dicloxacillin') || d.contains('piperacillin');

  static bool _isSulfaAllergy(String a) =>
      a.contains('sulfa') || a.contains('sulfonamide') || a.contains('sulfamethoxazole');

  static bool _isSulfaDrug(String d) =>
      d.contains('sulfamethoxazole') || d.contains('trimethoprim') || d.contains('cotrimoxazole') ||
      d.contains('sulfa') || d.contains('sulphamethoxazole');

  static bool _isNsaidAllergy(String a) =>
      a.contains('aspirin') || a.contains('nsaid') || a.contains('ibuprofen') || a.contains('naproxen');

  static bool _isNsaidDrug(String d) =>
      d.contains('ibuprofen') || d.contains('naproxen') || d.contains('aspirin') ||
      d.contains('diclofenac') || d.contains('indomethacin') || d.contains('celecoxib') ||
      d.contains('mefenamic') || d.contains('ketoprofen') || d.contains('piroxicam');

  static bool _isCephalosporinAllergy(String a) =>
      a.contains('cephalosporin') || a.contains('cefuroxime') || a.contains('ceftriaxone') ||
      a.contains('cefalexin') || a.contains('cephalexin');

  static bool _isCephalosporinDrug(String d) =>
      d.contains('cef') || d.contains('ceph');

  static bool _isErythromycinAllergy(String a) =>
      a.contains('erythromycin') || a.contains('macrolide') || a.contains('azithromycin');

  static bool _isMacrolideDrug(String d) =>
      d.contains('azithromycin') || d.contains('erythromycin') || d.contains('clarithromycin') ||
      d.contains('roxithromycin');

  static bool _isCodeineAllergy(String a) =>
      a.contains('codeine') || a.contains('opioid') || a.contains('morphine') || a.contains('opiate');

  static bool _isOpioidDrug(String d) =>
      d.contains('codeine') || d.contains('morphine') || d.contains('tramadol') ||
      d.contains('fentanyl') || d.contains('oxycodone') || d.contains('hydrocodone') ||
      d.contains('pethidine') || d.contains('dihydrocodeine');

  static bool _isMetronidazoleAllergy(String a) =>
      a.contains('metronidazole') || a.contains('flagyl');

  static bool _isStatinAllergy(String a) =>
      a.contains('statin') || a.contains('myopathy') || a.contains('atorvastatin') ||
      a.contains('simvastatin');

  static bool _isStatinDrug(String d) =>
      d.contains('statin') || d.contains('atorvastatin') || d.contains('simvastatin') ||
      d.contains('rosuvastatin') || d.contains('pravastatin') || d.contains('lovastatin') ||
      d.contains('fluvastatin');

  static bool _isWarfarin(String d) =>
      d.contains('warfarin') || d.contains('acenocoumarol');

  static bool _isAntibioticAffectingWarfarin(String d) =>
      d.contains('metronidazole') || d.contains('ciprofloxacin') || d.contains('fluconazole') ||
      d.contains('clarithromycin') || d.contains('erythromycin') || d.contains('trimethoprim');

  static bool _isMetformin(String d) =>
      d.contains('metformin');

  static bool _isContrastedOrAlcohol(String d) =>
      d.contains('alcohol') || d.contains('iodinated') || d.contains('contrast');

  static bool _isMaoi(String d) =>
      d.contains('phenelzine') || d.contains('tranylcypromine') || d.contains('isocarboxazid') ||
      d.contains('selegiline') || d.contains('rasagiline') || d.contains('moclobemide');

  static bool _isSsriOrTriptan(String d) =>
      _isSsri(d) || d.contains('sumatriptan') || d.contains('zolmitriptan') ||
      d.contains('tramadol') || d.contains('tryptophan') || d.contains('lithium');

  static bool _isSsri(String d) =>
      d.contains('fluoxetine') || d.contains('sertraline') || d.contains('citalopram') ||
      d.contains('escitalopram') || d.contains('paroxetine') || d.contains('fluvoxamine') ||
      d.contains('venlafaxine') || d.contains('duloxetine');

  static bool _isAceInhibitor(String d) =>
      d.contains('lisinopril') || d.contains('ramipril') || d.contains('enalapril') ||
      d.contains('captopril') || d.contains('perindopril') || d.contains('fosinopril');

  static bool _isDigoxin(String d) =>
      d.contains('digoxin') || d.contains('digitoxin');

  static bool _isCyp3a4Inhibitor(String d) =>
      d.contains('clarithromycin') || d.contains('erythromycin') || d.contains('ketoconazole') ||
      d.contains('itraconazole') || d.contains('fluconazole') || d.contains('ritonavir') ||
      d.contains('verapamil') || d.contains('diltiazem');

  static bool _isLithium(String d) =>
      d.contains('lithium');

  static bool _isAnticoagulant(String d) =>
      d.contains('warfarin') || d.contains('heparin') || d.contains('rivaroxaban') ||
      d.contains('apixaban') || d.contains('dabigatran') || d.contains('enoxaparin');

  static bool _isAntiplatelet(String d) =>
      d.contains('aspirin') || d.contains('clopidogrel') || d.contains('ticagrelor') ||
      d.contains('prasugrel') || d.contains('dipyridamole');

  static bool _isTetracycline(String d) =>
      d.contains('tetracycline') || d.contains('doxycycline') || d.contains('minocycline') ||
      d.contains('lymecycline');

  static bool _isQuinolone(String d) =>
      d.contains('ciprofloxacin') || d.contains('levofloxacin') || d.contains('ofloxacin') ||
      d.contains('norfloxacin') || d.contains('moxifloxacin');

  static bool _isCalciumOrAntacid(String d) =>
      d.contains('calcium') || d.contains('antacid') || d.contains('aluminium') ||
      d.contains('magnesium') || d.contains('iron') || d.contains('zinc') ||
      d.contains('sucralfate');

  static bool _isBetaBlocker(String d) =>
      d.contains('atenolol') || d.contains('metoprolol') || d.contains('propranolol') ||
      d.contains('bisoprolol') || d.contains('carvedilol') || d.contains('nebivolol') ||
      d.contains('labetalol');

  static bool _isCalciumChannelBlocker(String d) =>
      d.contains('verapamil') || d.contains('diltiazem') || d.contains('amlodipine') ||
      d.contains('nifedipine') || d.contains('felodipine') || d.contains('lercanidipine');

  static bool _isSildenafil(String d) =>
      d.contains('sildenafil') || d.contains('tadalafil') || d.contains('vardenafil') ||
      d.contains('avanafil');

  static bool _isNitrate(String d) =>
      d.contains('nitroglycerin') || d.contains('isosorbide') || d.contains('glyceryl trinitrate') ||
      d.contains('gtn') || d.contains('nitrate');

  static IconData severityIcon(WarningSeverity severity) {
    switch (severity) {
      case WarningSeverity.allergy:
        return Icons.warning_rounded;
      case WarningSeverity.major:
        return Icons.error_rounded;
      case WarningSeverity.moderate:
        return Icons.info_rounded;
      case WarningSeverity.minor:
        return Icons.info_outline_rounded;
    }
  }

  static Color severityColor(WarningSeverity severity) {
    switch (severity) {
      case WarningSeverity.allergy:
        return const Color(0xFFEF4444);
      case WarningSeverity.major:
        return const Color(0xFFF97316);
      case WarningSeverity.moderate:
        return const Color(0xFFF59E0B);
      case WarningSeverity.minor:
        return const Color(0xFF3B82F6);
    }
  }

  static String severityLabel(WarningSeverity severity) {
    switch (severity) {
      case WarningSeverity.allergy:
        return 'ALLERGY';
      case WarningSeverity.major:
        return 'MAJOR';
      case WarningSeverity.moderate:
        return 'MODERATE';
      case WarningSeverity.minor:
        return 'MINOR';
    }
  }
}
