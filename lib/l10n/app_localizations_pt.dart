// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get generalLoading => 'Carregando...';

  @override
  String get generalError => 'Erro';

  @override
  String generalErrorWithDescription(String error) {
    return 'Erro: $error';
  }

  @override
  String get generalRetry => 'Tentar de novo';

  @override
  String get generalCancel => 'Cancelar';

  @override
  String get generalCreate => 'Criar';

  @override
  String get generalOk => 'Ok';

  @override
  String get generalSave => 'Salvar';

  @override
  String get generalDelete => 'Excluir';

  @override
  String get generalEdit => 'Editar';

  @override
  String get generalAdd => 'Adicionar';

  @override
  String get generalClose => 'Fechar';

  @override
  String get generalPrivacyZones => 'Áreas de Privacidade';

  @override
  String get generalSettings => 'Configurações';

  @override
  String get generalShare => 'Compartilhar';

  @override
  String generalTrackDuration(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String generalTrackDurationShort(String hours, String minutes) {
    return '$hours:$minutes h';
  }

  @override
  String generalTrackDistance(String distance) {
    return '$distance km';
  }

  @override
  String get generalExport => 'Exportar';

  @override
  String get generalLogin => 'Entrar';

  @override
  String get generalLogout => 'Sair';

  @override
  String get generalRegister => 'Registrar-se';

  @override
  String get generalProceed => 'Prosseguir';

  @override
  String get homeBottomBarHome => 'Início';

  @override
  String get homeBottomBarTracks => 'Trajetos';

  @override
  String tracksAppBarSumTracks(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trajetos',
      one: '1 trajeto',
      zero: 'Nenhum trajeto',
    );
    return '$_temp0';
  }

  @override
  String get tracksNoTracks => 'Nenhum trajeto disponível';

  @override
  String get tracksTrackDeleted => 'Trajeto excluído';

  @override
  String get openSenseMapLogin => 'Entrar com openSenseMap';

  @override
  String get openSenseMapLoginDescription => 'Faça login para compartilhar seus dados.';

  @override
  String get openSenseMapLogout => 'Sair';

  @override
  String get openSenseMapEmail => 'E-mail';

  @override
  String get openSenseMapPassword => 'Senha';

  @override
  String get openSenseMapEmailErrorEmpty => 'O e-mail não pode estar vazio';

  @override
  String get openSenseMapEmailErrorInvalid => 'Endereço de e-mail inválido';

  @override
  String get openSenseMapPasswordErrorEmpty => 'A senha não pode estar vazia';

  @override
  String get openSenseMapLoginFailed => 'Falha no login';

  @override
  String get openSenseMapRegisterName => 'Nome';

  @override
  String get openSenseMapRegisterNameErrorEmpty => 'O nome não pode estar vazio';

  @override
  String get openSenseMapRegisterPasswordConfirm => 'Confirmar senha';

  @override
  String get openSenseMapRegisterPasswordConfirmErrorEmpty => 'A confirmação da senha não pode estar vazia';

  @override
  String get openSenseMapRegisterPasswordErrorMismatch => 'As senhas não coincidem';

  @override
  String get openSenseMapRegisterPasswordErrorCharacters => 'A senha deve conter pelo menos 8 caracteres';

  @override
  String get openSenseMapRegisterFailed => 'Falha no registro';

  @override
  String get openSenesMapRegisterAcceptTermsPrefix => 'Eu aceito os';

  @override
  String get openSenseMapRegisterAcceptTermsPrivacy => 'termos de privacidade';

  @override
  String get openSenseMapRegisterAcceptTermsError => 'Você deve aceitar os termos de privacidade';

  @override
  String get connectionButtonConnect => 'Conectar';

  @override
  String get connectionButtonDisconnect => 'Desconectar';

  @override
  String get connectionButtonConnecting => 'Conectando...';

  @override
  String get connectionButtonReconnecting => 'Reconectando...';

  @override
  String get connectionButtonStart => 'Iniciar';

  @override
  String get connectionButtonStop => 'Parar';

  @override
  String get bleDeviceSelectTitle => 'Toque para conectar';

  @override
  String get noBleDevicesFound => 'Nenhuma senseBox encontrada. Certifique-se de que sua senseBox está ligada, toque fora desta janela e tente novamente.';

  @override
  String get selectOrCreateBox => 'Selecionar ou criar senseBox';

  @override
  String get createBoxTitle => 'Criar senseBox:bike';

  @override
  String get createBoxModel => 'Modelo';

  @override
  String get createBoxModelErrorEmpty => 'Por favor, selecione um modelo';

  @override
  String get createBoxName => 'Nome';

  @override
  String get createBoxNameError => 'O nome deve ter entre 2 e 50 caracteres';

  @override
  String get createBoxGeolocationCurrentPosition => 'Sua posição atual será usada';

  @override
  String get openSenseMapBoxSelectionNoBoxes => 'Nenhum senseBox disponível';

  @override
  String get openSenseMapBoxSelectionCreateHint => 'Crie um usando o botão \'+\'';

  @override
  String get openSenseMapBoxSelectionUnnamedBox => 'senseBox sem nome';

  @override
  String get openSenseMapBoxSelectionIncompatible => 'Não compatível com senseBox:bike';

  @override
  String get settingsGeneral => 'Geral';

  @override
  String get settingsOther => 'Outros';

  @override
  String get settingsVibrateOnDisconnect => 'Vibrar ao desconectar';

  @override
  String get settingsAbout => 'Sobre';

  @override
  String get settingsPrivacyPolicy => 'Política de Privacidade';

  @override
  String settingsVersion(String versionNumber) {
    return 'Versão: $versionNumber';
  }

  @override
  String get settingsContact => 'Ajuda ou feedback?';

  @override
  String get settingsEmail => 'E-mail';

  @override
  String get settingsGithub => 'GitHub issue';

  @override
  String get privacyZonesStart => 'Toque no mapa para começar a desenhar uma área. Toque na marca de seleção para finalizar.';

  @override
  String get privacyZonesDelete => 'Toque em uma área para excluí-la. Toque na marca de seleção para finalizar.';

  @override
  String get trackDetailsPermissionsError => 'Permissão negada para salvar o arquivo no armazenamento externo.';

  @override
  String get trackDetailsFileSaved => 'Arquivo CSV salvo na pasta Downloads.';

  @override
  String get trackDetailsExport => 'Exportação de dados do trajeto em CSV.';

  @override
  String get trackDetailsNoData => 'Nenhum dado disponível.';

  @override
  String get trackDetailsLoadingError => 'Erro ao carregar o trajeto.';

  @override
  String get trackDetailsNoTrackData => 'Nenhum trajeto disponível.';

  @override
  String get trackDelete => 'Excluir Trajeto';

  @override
  String get trackDeleteConfirmation => 'Tem certeza de que deseja excluir este trajeto?';

  @override
  String get sensorTemperature => 'Temperatura';

  @override
  String get sensorHumidity => 'Umidade Rel.';

  @override
  String get sensorFinedustPM10 => 'Material Particulado PM10';

  @override
  String get sensorFinedustPM4 => 'Material Particulado PM4';

  @override
  String get sensorFinedustPM25 => 'Material Particulado PM2,5';

  @override
  String get sensorFinedustPM1 => 'Material Particulado PM1';

  @override
  String get sensorDistance => 'Distância de Ultrapassagem';

  @override
  String get sensorOvertaking => 'Manobra de Ultrapassagem';

  @override
  String get sensorOvertakingShort => 'Ultrapassagem';

  @override
  String get sensorSurface => 'Superfície';

  @override
  String get sensorSurfaceAsphalt => 'Superfície: Asfalto';

  @override
  String get sensorSurfaceAsphaltShort => 'Asfalto';

  @override
  String get sensorSurfaceSett => 'Superfície: Paralelepípedo';

  @override
  String get sensorSurfaceSettShort => 'Paralelepípedo';

  @override
  String get sensorSurfaceCompacted => 'Superfície: Compactada';

  @override
  String get sensorSurfaceCompactedShort => 'Compacted';

  @override
  String get sensorSurfacePaving => 'Superfície: Pavimentada';

  @override
  String get sensorSurfacePavingShort => 'Pavimentada';

  @override
  String get sensorSurfaceStanding => 'Parado';

  @override
  String get sensorSurfaceAnomaly => 'Irregularidade no Piso';

  @override
  String get sensorSpeed => 'Velocidade';

  @override
  String get sensorAccelerationX => 'Aceleração X';

  @override
  String get sensorAccelerationY => 'Aceleração Y';

  @override
  String get sensorAccelerationZ => 'Aceleração Z';

  @override
  String get sensorGPSLat => 'Latitude GPS';

  @override
  String get sensorGPSLong => 'Longitude GPS';

  @override
  String get sensorGPSSpeed => 'Velocidade GPS';

  @override
  String get sensorGPSError => 'Erro no GPS';

  @override
  String get sensorAcceleration => 'Aceleração';

  @override
  String get sensorFinedust => 'Material Particulado';

  @override
  String get sensorDistanceShort => 'Distância';

  @override
  String get campaignLoadError => 'Falha ao carregar a lista de campanhas.';

  @override
  String get selectCampaign => 'Selecionar campanha';

  @override
  String get noCampaignsAvailable => 'Não há campanhas disponíveis';

  @override
  String get loginScreenTitle => 'openSenseMap Conta';

  @override
  String get connectionButtonEnableBluetooth => 'Ativar Bluetooth';

  @override
  String get errorNoLocationAccess => 'Para gravar faixas, permita que a aplicação aceda à localização atual do dispositivo nas definições do telefone.';

  @override
  String get errorNoScanAccess => 'Para se conectar à SenseBox, permita que a aplicação procure dispositivos próximos nas definições do telemóvel.';

  @override
  String get errorNoSenseBoxSelected => 'Para permitir o envio de dados do sensor para a nuvem, inicie sessão na sua conta do openSenseMap e selecione a caixa.';

  @override
  String get errorExportDirectoryAccess => 'Erro ao acessar o diretório de exportação. Por favor, verifique se o aplicativo tem permissão para acessar o armazenamento.';

  @override
  String get errorLoginFailed => 'Falha no login. Por favor, verifique suas credenciais.';

  @override
  String get errorRegistrationFailed => 'Falha no registro. Por favor, verifique suas credenciais.';

  @override
  String get errorBleConnectionFailed => 'A conexão com a senseBox foi perdida. Por favor, certifique-se de que o Bluetooth está ativado e a senseBox está ligada.';

  @override
  String get selectCsvFormat => 'Selecionar formato CSV';

  @override
  String get regularCsv => 'CSV padrão';

  @override
  String get openSenseMapCsv => 'CSV openSenseMap';

  @override
  String get settingsDeleteAllData => 'Excluir Todos os Dados';

  @override
  String get settingsDeleteAllDataConfirmation => 'Tem certeza de que deseja excluir todos os dados? Esta ação é irreversível.';

  @override
  String get settingsDeleteAllDataSuccess => 'Todos os dados foram excluídos com sucesso.';

  @override
  String get settingsDeleteAllDataError => 'Falha ao excluir todos os dados. Por favor, tente novamente.';

  @override
  String get accountManagement => 'Gerenciamento de Conta';

  @override
  String get deleteAllHint => 'Isso excluirá todas as suas faixas do aplicativo.';

  @override
  String get generalConfirmation => 'Confirmação';

  @override
  String get privacyPolicyAccept => 'Eu li e aceito a política de privacidade.';

  @override
  String get trackNoGeolocations => 'Nenhuma geolocalização disponível para este trajeto.';

  @override
  String get tracksAppBarTitle => 'Seus trajetos';

  @override
  String get loadMore => 'Carregar mais';

  @override
  String get tracksStatisticsTitle => 'Estatísticas do Trajeto';

  @override
  String get tracksStatisticsTotalData => 'Dados Totais';

  @override
  String get tracksStatisticsThisWeek => 'Esta Semana';

  @override
  String get tracksStatisticsRidesInfo => 'viagens concluídas';

  @override
  String get tracksStatisticsDistanceInfo => 'distância percorrida';

  @override
  String get tracksStatisticsTimeInfo => 'tempo gasto na estrada';

  @override
  String get trackStatistics => 'Estatísticas do Trajeto';
}
