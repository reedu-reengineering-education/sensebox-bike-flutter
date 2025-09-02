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
  String get generalUpload => 'Enviar';

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
  String get settingsUploadMode => 'Modo de Upload';

  @override
  String get settingsUploadModeDirect => 'Upload Direto (Beta)';

  @override
  String get settingsUploadModePostRide => 'Upload Pós-Corrida';

  @override
  String get settingsUploadModeDescription => 'Escolha quando enviar seus dados durante a gravação';

  @override
  String settingsUploadModeCurrent(String mode) {
    return 'Atual: $mode';
  }

  @override
  String get settingsUploadModePostRideTitle => 'Enviar dados após o término da gravação';

  @override
  String get settingsUploadModePostRideDescription => '• Os dados são armazenados localmente durante a gravação\n• O envio acontece de uma vez quando você terminar\n• Mais confiável e estável\n• Consome menos bateria durante a gravação';

  @override
  String get settingsUploadModeDirectTitle => 'Enviar dados em tempo real durante a gravação (experimental)';

  @override
  String get settingsUploadModeDirectDescription => '• Os dados são enviados imediatamente conforme são coletados\n• Compartilhamento de dados em tempo real (experimental)\n• Requer conexão com a internet estável\n• Pode consumir mais bateria durante a gravação';

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
  String get errorNoLocationAccess => 'Os serviços de localização estão desativados ou o acesso é negado. Para gravar faixas, ative os serviços de localização e permita que a aplicação aceda à sua localização nas definições do telefone.';

  @override
  String get errorNoScanAccess => 'Para se conectar à SenseBox, permita que a aplicação procure dispositivos próximos nas definições do telemóvel.';

  @override
  String get errorNoSenseBoxSelected => 'Para permitir o envio de dados do sensor para a nuvem, inicie sessão na sua conta do openSenseMap e selecione a caixa.';

  @override
  String get errorExportDirectoryAccess => 'Erro ao acessar o diretório de exportação. Por favor, verifique se o aplicativo tem permissão para acessar o armazenamento.';

  @override
  String get errorLoginFailed => 'Falha no login. Por favor, verifique suas credenciais e tente novamente.';

  @override
  String get errorRegistrationFailed => 'Falha no registro. Por favor, verifique suas credenciais e tente novamente.';

  @override
  String get errorBleConnectionFailed => 'A conexão com a senseBox foi perdida. Por favor, certifique-se de que o Bluetooth está ativado e a senseBox está ligada.';

  @override
  String get errorUploadFailed => 'Falha no upload de dados. Por favor, verifique sua conexão com a internet e tente novamente.';

  @override
  String get errorPermanentAuthentication => 'Falha permanente na autenticação. Por favor, faça login para enviar dados.';

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

  @override
  String get uploadProgressTitle => 'Progresso do Upload';

  @override
  String get uploadProgressPreparing => 'Preparando upload...';

  @override
  String get uploadProgressUploading => 'Enviando dados do trajeto...';

  @override
  String get uploadProgressInfo => 'Por favor, não feche o aplicativo durante o upload. Dependendo do comprimento do seu trajeto, isso pode levar algum tempo.\n\nSe quiser enviar os dados do seu trajeto mais tarde, pode fazê-lo a partir da tela de visão geral do trajeto.';

  @override
  String get uploadProgressRetrying => 'Tentando upload novamente...';

  @override
  String get uploadProgressCompleted => 'Upload concluído com sucesso';

  @override
  String get uploadProgressFailed => 'Upload falhou';

  @override
  String get uploadProgressAuthenticationFailed => 'Autenticação necessária';

  @override
  String uploadProgressChunks(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total blocos',
      one: '1 bloco',
      zero: '0 blocos',
    );
    return '$completed de $_temp0 enviados';
  }

  @override
  String uploadProgressPercentage(int percentage) {
    return '$percentage% concluído';
  }

  @override
  String get uploadProgressAuthenticationError => 'Por favor, faça login para enviar dados.';

  @override
  String get uploadProgressNetworkError => 'Falha na conexão de rede. Verifique sua conexão com a internet e tente novamente.';

  @override
  String get uploadProgressGenericError => 'Upload falhou. Tente novamente.';

  @override
  String get uploadConfirmTitle => 'Enviar Dados do Trajeto';

  @override
  String get uploadConfirmMessage => 'Gostaria de enviar os dados do seu trajeto agora ou mais tarde?';

  @override
  String get uploadConfirmUploadNow => 'Enviar agora';

  @override
  String get trackStatusUploaded => 'Enviado';

  @override
  String trackStatusUploadedAt(String date) {
    return 'Enviado em $date';
  }

  @override
  String get trackStatusNotUploaded => 'Não enviado';

  @override
  String get trackStatusUploadFailed => 'Envio falhou';

  @override
  String trackStatusUploadFailedAt(Object date) {
    return 'Upload failed on $date';
  }

  @override
  String get trackDirectUploadInfo => 'Este trajeto foi enviado em tempo real durante o seu passeio (se estiver logado). Quer enviá-lo novamente? Use o botão acima!';

  @override
  String get trackDirectUploadAuthFailed => 'Este trajeto falhou ao ser enviado em tempo real porque você não estava logado. Por favor, faça login e tente enviar novamente.';

  @override
  String get trackFilterAll => 'Todos';

  @override
  String get trackFilterUnuploaded => 'Não enviados';

  @override
  String get trackUploadRetryFailed => 'Tentativa de envio falhou. Tente novamente.';

  @override
  String get errorTrackNoGeolocations => 'Trajeto não possui dados de geolocalização e não pode ser enviado.';
}
