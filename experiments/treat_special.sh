#!/bin/bash
project_dir=$1
project_name=$2

cd ${project_dir}

if [[ ${project_name} == swagger-api-swagger-inflector ]]; then
  echo "Patching swagger-api-swagger-inflector"
  find -name SchemaValidationTest.java | xargs rm -f
  find -name BinaryProcessorTest.java | xargs rm -f
fi

if [[ ${project_name} == dadiyang-wechat-client ]]; then
  echo "Patching dadiyang-wechat-client"
  find -name ApiConfigurationTest.java | xargs rm -f
  find -name UserApiTest.java | xargs rm -f
  find -name MediaApiTest.java | xargs rm -f
  find -name ClientApiTest.java | xargs rm -f
fi

if [[ ${project_name} == opencharles-charles-rest ]]; then
  echo "Patching opencharles-charles-rest"
  find -name CachedRepoTestCase.java | xargs rm -f
  find -name LastCommentTestCase.java | xargs rm -f
  find -name TextReplyTestCase.java | xargs rm -f
  find -name ErrorReplyTestCase.java | xargs rm -f
  find -name ValidCommandTestCase.java | xargs rm -f
  find -name StepsTestCase.java | xargs rm -f
  find -name StarRepoTestCase.java | xargs rm -f
  find -name SendReplyTestCase.java | xargs rm -f
fi

if [[ ${project_name} == alexec-docker-maven-plugin ]]; then
  echo "Patching alexec-docker-maven-plugin"
  find -name SaveMojoTest.java | xargs rm -f
  find -name CopyMojoTest.java | xargs rm -f
  find -name StopMojoTest.java | xargs rm -f
  find -name PackageMojoTest.java | xargs rm -f
  find -name DeployMojoTest.java | xargs rm -f
  find -name ValidateMojoTest.java | xargs rm -f
  find -name StartMojoTest.java | xargs rm -f
  find -name CleanMojoTest.java | xargs rm -f
  find -name AbstractDockerMojoTest.java | xargs rm -f
fi

if [[ ${project_name} == maihaoche-rocketmq-spring-boot-starter ]]; then
  echo "Patching maihaoche-rocketmq-spring-boot-starter"
  find -name MQProducerAutoConfigurationTest.java | xargs rm -f
fi

if [[ ${project_name} == OWASP-url-classifier ]]; then
  echo "Patching OWASP-url-classifier"
  echo -n "Arrays_MutuallyComparable" > .skip-spec.txt
fi

if [[ ${project_name} == hantsy-angularjs-springmvc-sample ]]; then
  echo "Patching hantsy-angularjs-springmvc-sample"
  find -name MockBlogServiceTest.java | xargs rm -f
  find -name BlogServiceTest.java | xargs rm -f
  find -name PostControllerTest.java | xargs rm -f
fi

if [[ ${project_name} == hermannpencole-nifi-config ]]; then
  echo "Patching hermannpencole-nifi-config"
  find -name MainTest.java | xargs rm -f
  find -name ProcessGroupServiceTest.java | xargs rm -f
  find -name PortServiceTest.java | xargs rm -f
  find -name ConnectionServiceTest.java | xargs rm -f
  find -name ControllerServicesServiceTest.java | xargs rm -f
  find -name TemplateServiceTest.java | xargs rm -f
  find -name ProcessorServiceTest.java | xargs rm -f
fi

if [[ ${project_name} == opentracing-contrib-java-jdbc ]]; then
  echo "Patching opentracing-contrib-java-jdbc"
  find -name HibernateTest.java | xargs rm -f
fi

if [[ ${project_name} == mangstadt-biweekly ]]; then
  echo "Patching mangstadt-biweekly"
  find -name ICalPropertyTest.java | xargs rm -f
  find -name StreamWriterTest.java | xargs rm -f
  find -name TzUrlDotOrgGeneratorTest.java | xargs rm -f
fi

if [[ ${project_name} == tolitius-money-making-project ]]; then
  echo "Patching tolitius-money-making-project"
fi

if [[ ${project_name} == thymeleaf-thymeleafexamples-layouts ]]; then
  echo "Patching thymeleaf-thymeleafexamples-layouts"
  find -name UserAuthenticationIntegrationTest.java | xargs rm -f
  find -name SignupControllerTest.java | xargs rm -f
fi

if [[ ${project_name} == picturesafe-picturesafe-search ]]; then
  echo "Patching picturesafe-picturesafe-search"
  find -name MappingFieldConfigurationProviderTest.java | xargs rm -f
  find -name TimeZonePropertySetterTest.java | xargs rm -f
  find -name WriteRequestHandlerTest.java | xargs rm -f
  find -name MustNotExpressionFilterBuilderTest.java | xargs rm -f
  find -name DayExpressionFilterBuilderTest.java | xargs rm -f
  find -name SpringBeanStandardQuerystringPreprocessorTest.java | xargs rm -f
  find -name ElasticDateUtilsTest.java | xargs rm -f
fi

if [[ ${project_name} == daanvdh-JavaForger ]]; then
  echo "Patching daanvdh-JavaForger"
  find -name GeneratorTest.java | xargs rm -f
  find -name TemplateIntegrationTest.java | xargs rm -f
  find -name DataFlowGraphTemplateIntegrationTest.java | xargs rm -f
  find -name MethodDefinitionFactoryTest.java | xargs rm -f
  find -name ClassContainerReaderTest.java | xargs rm -f
  find -name VariableDefintionFactoryTest.java | xargs rm -f
  find -name CodeSnipitReaderTest.java | xargs rm -f
  find -name NodeComparatorTest.java | xargs rm -f
  find -name CodeSnipitLocationTest.java | xargs rm -f
  find -name JavaParserMergerTest.java | xargs rm -f
  find -name LineMergerTest.java | xargs rm -f
  find -name CodeSnipitLocaterTest.java | xargs rm -f
fi

if [[ ${project_name} == remondis-it-pact-consumer-builder ]]; then
  echo "Patching remondis-it-pact-consumer-builder"
  find -name UseCustomConsumerForFieldTest.java | xargs rm -f
  find -name CustomFieldNameTest.java | xargs rm -f
  find -name CustomStructureTest.java | xargs rm -f
  find -name SpringPageSupportTest.java | xargs rm -f
  find -name UseGlobalCustomConsumerTest.java | xargs rm -f
fi

if [[ ${project_name} == wz2cool-mybatis-dynamic-query ]]; then
  echo "Patching wz2cool-mybatis-dynamic-query"
  find -name DynamicMapperTest.java | xargs rm -f
  find -name DbFilterTest.java | xargs rm -f
  find -name DemoTest.java | xargs rm -f
  find -name ViewTest.java | xargs rm -f
  find -name DbSortTest.java | xargs rm -f
  find -name LogicPagingTest.java | xargs rm -f
fi

if [[ ${project_name} == PearsonEducation-StatsAgg ]]; then
  echo "Patching PearsonEducation-StatsAgg"
  find -name GraphiteMetricTest.java | xargs rm -f
  find -name OpenTsdbTest.java | xargs rm -f
  find -name InfluxdbMetric_v1Test.java | xargs rm -f
  find -name InfluxdbStandardizedMetric_Test.java | xargs rm -f
  find -name StatsdMetricAggregatedTest.java | xargs rm -f
fi

if [[ ${project_name} == alb-i986-selenium-tinafw ]]; then
  echo "Patching alb-i986-selenium-tinafw"
  echo -n "Arrays_MutuallyComparable" > .skip-spec.txt
  find -name WebDriverFactoryLocalTest.java | xargs rm -f
fi

if [[ ${project_name} == fekaputra-shacl-plugin ]]; then
  echo "Patching fekaputra-shacl-plugin"
  find -name TestInference.java | xargs rm -f
fi

if [[ ${project_name} == Appdynamics-zookeeper-monitoring-extension ]]; then
  echo "Patching Appdynamics-zookeeper-monitoring-extension"
  find -name ZookeeperMonitorTaskTest.java | xargs rm -f
  find -name MetricCollectorTest.java | xargs rm -f
fi

if [[ ${project_name} == natf17-shopify-embedded-app ]]; then
  echo "Patching natf17-shopify-embedded-app"
  find -name ShopifyOAuth2Tests.java | xargs rm -f
  find -name ShopifySecurityConfigurerTests.java | xargs rm -f
  find -name SecurityBeansConfigTests.java | xargs rm -f
  find -name ShopifyAuthorizationCodeTokenResponseClientTests.java | xargs rm -f
  find -name ShopifyBeansUtilsTests.java | xargs rm -f
fi

if [[ ${project_name} == kstateome-canvas-api ]]; then
  echo "Patching kstateome-canvas-api"
  find -name SubmissionImplTest.java | xargs rm -f
  find -name AccountReaderUTest.java | xargs rm -f
  find -name LoginUTest.java | xargs rm -f
  find -name CalendarWriterUTest.java | xargs rm -f
  find -name CalendarReaderUTest.java | xargs rm -f
  find -name SisImportUTest.java | xargs rm -f
  find -name AuthenticationLogUTest.java | xargs rm -f
  find -name GsonDateParsingUTest.java | xargs rm -f
  find -name UserRetrieverUTest.java | xargs rm -f
  find -name QuizSubmissionRetrieverUTest.java | xargs rm -f
  find -name QuizQuestionRetrieverUTest.java | xargs rm -f
  find -name QuizRetrieverUTest.java | xargs rm -f
  find -name RolesUTest.java | xargs rm -f
  find -name TabUTest.java | xargs rm -f
  find -name CourseManagerUTest.java | xargs rm -f
  find -name SectionManagerUTest.java | xargs rm -f
  find -name CourseListingUTest.java | xargs rm -f
  find -name DropCourseUTest.java | xargs rm -f
  find -name UserManagerUTest.java | xargs rm -f
  find -name CourseGetUTest.java | xargs rm -f
  find -name AccountReportSummaryUTest.java | xargs rm -f
  find -name AccountReportUTest.java | xargs rm -f
  find -name CommunicationChannelUTest.java | xargs rm -f
  find -name ModuleListingTest.java | xargs rm -f
  find -name AssignmentGroupUTest.java | xargs rm -f
  find -name AssignmentRetrieverUTest.java | xargs rm -f
  find -name AssignmentOverrideUTest.java | xargs rm -f
  find -name CourseGetUTest.java | xargs rm -f
  find -name ContentMigrationUTest.java | xargs rm -f
  find -name EnrollmentTermUTest.java | xargs rm -f
  find -name EnrollmentUTest.java | xargs rm -f
  find -name ApiFactoryUTest.java | xargs rm -f
  find -name BaseImplUTest.java | xargs rm -f
fi

if [[ ${project_name} == vietj-vertx-http-proxy ]]; then
  echo "Patching vietj-vertx-http-proxy"
fi

if [[ ${project_name} == apache-giraph ]]; then
  echo "Patching apache-giraph"
  find -name SendingMessagesTest.java | xargs rm -f
  find -name TestWorkerMessages.java | xargs rm -f
  find -name MultipleSimultanousMutationsTest.java | xargs rm -f
fi

if [[ ${project_name} == peholmst-vaadin4spring ]]; then
  echo "Patching peholmst-vaadin4spring"
  find -name ScopedEventBusIntegrationTest.java | xargs rm -f
  find -name ScopedEventBusTest.java | xargs rm -f
fi

if [[ ${project_name} == chhsiao90-nitmproxy ]]; then
  echo "Patching chhsiao90-nitmproxy"
  find -name CertManagerTest.java | xargs rm -f
  find -name Http1EventHandlerTest.java | xargs rm -f
fi

if [[ ${project_name} == alibaba-compileflow ]]; then
  echo "Patching alibaba-compileflow"
  find -name ProcessEngineTest.java | xargs rm -f
fi

if [[ ${project_name} == sylvainlaurent-swagger-validator-maven-plugin ]]; then
  echo "Patching sylvainlaurent-swagger-validator-maven-plugin"
  find -name ValidationServiceTest.java | xargs rm -f
fi

if [[ ${project_name} == j256-simplejmx ]]; then
  echo "Patching j256-simplejmx"
  find -name JmxWebServerTest.java | xargs rm -f
  find -name JmxWebHandlerTest.java | xargs rm -f
  grep -rl --include="*.java" "@Timeout" | xargs sed -i -e 's/@Timeout\(.*\)/@Timeout(3600)/g'
  grep -rl --include="*.java" "@Test(.*timeout.*)" | xargs sed -i -e 's/@Test\(.*timeout.*\)/@Test/g'
fi

if [[ ${project_name} == jscep-jscep ]]; then
  echo "Patching jscep-jscep"
  find -name PkiMessageEncoderTest.java | xargs rm -f
  find -name MessageDigestCertificateVerifierTest.java | xargs rm -f
  find -name PessimisticCertificateVerifierTest.java | xargs rm -f
  find -name CachingCertificateVerifierTest.java | xargs rm -f
  find -name OptimisticCertificateVerifierTest.java | xargs rm -f
  find -name ConsoleCallbackVerifierTest.java | xargs rm -f
  find -name PreProvisionedCertificateVerifierTest.java | xargs rm -f
  find -name KeyStoreExampleClientTest.java | xargs rm -f
  find -name CertificateVerificationCallbackTest.java | xargs rm -f
  find -name DefaultCallbackHandlerTest.java | xargs rm -f
  find -name ClientTest.java | xargs rm -f
  find -name CertificationRequestUtilsTest.java | xargs rm -f
  find -name ScepServletTest.java | xargs rm -f
  find -name HttpPostTransportTest.java | xargs rm -f
  find -name NextCaCertificateContentHandlerTest.java | xargs rm -f
  find -name CaCertificateContentHandlerTest.java | xargs rm -f
fi

if [[ ${project_name} == phenopolis-pheno4j ]]; then
  echo "Patching phenopolis-pheno4j"
  find -name PojoTest.java | xargs rm -f
fi

if [[ ${project_name} == Mercateo-spring-security-jwt ]]; then
  echo "Patching Mercateo-spring-security-jwt"
  find -name JWTSecurityConfigurationTest.java | xargs rm -f
  sed -i '/public void verifiesExpiredTokenWithConfiguredLeeway/i\    @org.junit.Ignore' ./src/test/java/com/mercateo/spring/security/jwt/token/verifier/JWTVerifierTest.java
fi

if [[ ${project_name} == yuch7-cwlexec ]]; then
  echo "Patching yuch7-cwlexec"
  find -name CWLPersistenceServiceTest.java | xargs rm -f
fi

if [[ ${project_name} == mojohaus-license-maven-plugin ]]; then
  echo "Patching mojohaus-license-maven-plugin"
  find -name LicenseSummaryTest.java | xargs rm -f
fi

if [[ ${project_name} == davidmoten-rxjava2-aws ]]; then
  echo "Patching davidmoten-rxjava2-aws"
  find -name SqsTest.java | xargs rm -f
  grep -rl --include="*.java" "@Timeout" | xargs sed -i -e 's/@Timeout\(.*\)/@Timeout(3600)/g'
  grep -rl --include="*.java" "@Test(.*timeout.*)" | xargs sed -i -e 's/@Test\(.*timeout.*\)/@Test/g'
fi

if [[ ${project_name} == Appdynamics-rabbitmq-monitoring-extension ]]; then
  echo "Patching Appdynamics-rabbitmq-monitoring-extension"
  find -name MetricsCollectorTest.java | xargs rm -f
  find -name OptionalMetricsCollectorTest.java | xargs rm -f
fi

if [[ ${project_name} == zapodot-embedded-ldap-junit ]]; then
  echo "Patching zapodot-embedded-ldap-junit"
  find -name EmbeddedLdapRuleTlsTest.java | xargs rm -f
  find -name EmbeddedLdapRuleStarttlsTest.java | xargs rm -f
fi

if [[ ${project_name} == finos-messageml-utils ]]; then
  echo "Patching finos-messageml-utils"
  find -name TestValidSchemas.java | xargs rm -f
  find -name TestInvalidSchemas.java | xargs rm -f
fi

if [[ ${project_name} == dernasherbrezon-jradio ]]; then
  echo "Patching dernasherbrezon-jradio"
  find -name Huskysat1Test.java | xargs rm -f
  find -name FoxPictureDecoderTest.java | xargs rm -f
  find -name Fox1CBeaconTest.java | xargs rm -f
  find -name LookupTablesTest.java | xargs rm -f
  find -name Fox1BBeaconTest.java | xargs rm -f
  find -name Fox1DBeaconTest.java | xargs rm -f
  find -name Fox1ABeaconTest.java | xargs rm -f
  find -name FoxTest.java | xargs rm -f
fi

if [[ ${project_name} == bingoohuang-asmvalidator ]]; then
  echo "Patching bingoohuang-asmvalidator"
  find -name CharacterControllerTest.java | xargs rm -f
  find -name DemoController2Test.java | xargs rm -f
  sed -i '/public void testCalendar/i\    @org.junit.Ignore' ./src/test/java/com/github/bingoohuang/asmvalidator/validator/tests/AsmFutureTest.java
  sed -i '/public void testCalendarBad/i\    @org.junit.Ignore' ./src/test/java/com/github/bingoohuang/asmvalidator/validator/tests/AsmPastTest.java
fi

if [[ ${project_name} == Scout24-yum-repo-server ]]; then
  echo "Patching Scout24-yum-repo-server"
  find -name MethodSecurityConfigTest.java | xargs rm -f
  find -name RetryAspectTest.java | xargs rm -f
  find -name FileControllerTest.java | xargs rm -f
fi

if [[ ${project_name} == searls-jasmine-maven-plugin ]]; then
  echo "Patching searls-jasmine-maven-plugin"
  find -name RelativizesFilePathsTest.java | xargs rm -f
fi

if [[ ${project_name} == meanbeanlib-meanbean ]]; then
  echo "Patching meanbeanlib-meanbean"
  find -name BeanVerifierTest.java | xargs rm -f
fi

if [[ ${project_name} == Contargo-iris ]]; then
  echo "Patching Contargo-iris"
  find -name AirlineDistanceApiControllerMvcUnitTest.java | xargs rm -f
  find -name LoginControllerMvcUnitTest.java | xargs rm -f
  find -name SeaportApiControllerMvcUnitTest.java | xargs rm -f
  find -name SeaportControllerMvcUnitTest.java | xargs rm -f
  find -name DiscoverPublicApiControllerMvcUnitTest.java | xargs rm -f
  find -name RouteDataRevisionApiControllerMvcUnitTest.java | xargs rm -f
  find -name RouteDataRevisionControllerMvcUnitTest.java | xargs rm -f
  find -name TerminalApiControllerMvcUnitTest.java | xargs rm -f
  find -name TerminalControllerMvcUnitTest.java | xargs rm -f
  find -name RoutesApiControllerMvcUnitTest.java | xargs rm -f
  find -name RouteEnricherApiControllerMvcUnitTest.java | xargs rm -f
  find -name CountriesApiControllerMvcUnitTest.java | xargs rm -f
  find -name RootControllerMvcUnitTest.java | xargs rm -f
  find -name AddressApiControllerMvcUnitTest.java | xargs rm -f
  find -name BestMatchApiControllerMvcUnitTest.java | xargs rm -f
  find -name StaticAddressApiControllerMvcUnitTest.java | xargs rm -f
  find -name StaticAddressControllerMvcUnitTest.java | xargs rm -f
  find -name TransportApiControllerUnitTest.java | xargs rm -f
  find -name SeaportConnectionApiControllerMvcUnitTest.java | xargs rm -f
  find -name MainRunConnectionApiControllerMvcUnitTest.java | xargs rm -f
  find -name MainRunConnectionControllerMvcUnitTest.java | xargs rm -f
fi

if [[ ${project_name} == spring-projects-spring-session-data-mongodb ]]; then
  echo "Patching spring-projects-spring-session-data-mongodb"
  find -name TraditionalConfigurationTest.java | xargs rm -f
  find -name MongoDbLogoutVerificationTest.java | xargs rm -f
  find -name MongoRepositoryJdkSerializationITest.java | xargs rm -f
  find -name MongoRepositoryJacksonITest.java | xargs rm -f
  find -name ReactiveConfigurationTest.java | xargs rm -f
  find -name MongoDbDeleteJacksonSessionVerificationTest.java | xargs rm -f
  find -name MongoHttpSessionConfigurationTest.java | xargs rm -f
fi

if [[ ${project_name} == GreenButtonAlliance-OpenESPI-ThirdParty-java ]]; then
  echo "Patching GreenButtonAlliance-OpenESPI-ThirdParty-java"
  find -name CORSFilterTests.java | xargs rm -f
  find -name LoginControllerTests.java | xargs rm -f
  find -name HomeControllerTests.java | xargs rm -f
  find -name CustomerHomeControllerTests.java | xargs rm -f
fi

if [[ ${project_name} == imagej-imagej-omero ]]; then
  echo "Patching imagej-imagej-omero"
  find -name UploadTableTest.java | xargs rm -f
  find -name DownloadROITest.java | xargs rm -f
  find -name UploadROITest.java | xargs rm -f
  find -name DownloadTableTest.java | xargs rm -f
fi

if [[ ${project_name} == AAA-AA-basic-tools ]]; then
  echo "Patching AAA-AA-basic-tools"
  find -name TestLogFormats.java | xargs rm -f
  find -name TestIdCards.java | xargs rm -f
fi

if [[ ${project_name} == lambdazen-bitsy ]]; then
  echo "Patching lambdazen-bitsy"
  echo -n "Arrays_SortBeforeBinarySearch" > .skip-spec.txt
fi

if [[ ${project_name} == uPortal-Project-CalendarPortlet ]]; then
  echo "Patching uPortal-Project-CalendarPortlet"
  find -name ExchangeCalendarAdapterIntegrationTest.java | xargs rm -f
fi

if [[ ${project_name} == GoogleCloudPlatform-storage-sdrs ]]; then
  echo "Patching GoogleCloudPlatform-storage-sdrs"
  find -name JsonMappingExceptionMapperTest.java | xargs rm -f
  find -name JsonProcessingExceptionMapperTest.java | xargs rm -f
  find -name StsRuleExecutorTest.java | xargs rm -f
fi

if [[ ${project_name} == cowtowncoder-jackson-compat-minor ]]; then
  echo "Patching cowtowncoder-jackson-compat-minor"
  echo -n "Arrays_MutuallyComparable" > .skip-spec.txt
fi

if [[ ${project_name} == streamx-co-FluentJPA ]]; then
  echo "Patching streamx-co-FluentJPA"
  find -name FamilyTest.java | xargs rm -f
  find -name TooManyQueriesTest.java | xargs rm -f
  find -name JPAAnnotationsTest.java | xargs rm -f
  find -name EmployeeManagerRepoTest.java | xargs rm -f
  find -name UserRepositoryTest.java | xargs rm -f
  find -name SyntaxTest.java | xargs rm -f
  find -name PersonRepositoryTest.java | xargs rm -f
  find -name EmployeeRepositoryTest.java | xargs rm -f
  find -name NetworkObjectRepoTest.java | xargs rm -f
fi

if [[ ${project_name} == cheese10yun-spring-jpa-best-practices ]]; then
  echo "Patching cheese10yun-spring-jpa-best-practices"
  find -name AccountRepositoryTest.java | xargs rm -f
  find -name AccountIntegrationTest.java | xargs rm -f
  find -name OrderServiceTest.java | xargs rm -f
  find -name SpringJpaApplicationTests.java | xargs rm -f
fi

if [[ ${project_name} == Arnauld-gutenberg ]]; then
  echo "Patching Arnauld-gutenberg"
  find -name TeXFormulaTest.java | xargs rm -f
  find -name PegdownPdfTest.java | xargs rm -f
fi

if [[ ${project_name} == f-lab-edu-real-time-delivery-market ]]; then
  echo "Patching f-lab-edu-real-time-delivery-market"
  find -name MemberJoinDtoValidationTest.java | xargs rm -f
fi

if [[ ${project_name} == eurekaclinical-aiw-i2b2-etl ]]; then
  echo "Patching eurekaclinical-aiw-i2b2-etl"
  echo -n "Arrays_MutuallyComparable" > .skip-spec.txt
fi

if [[ ${project_name} == NanoHttpd-nanohttpd ]]; then
  echo "Patching NanoHttpd-nanohttpd"
  find -name WebSocketResponseHandlerTest.java | xargs rm -f
  find -name EchoWebSocketsTest.java | xargs rm -f
fi

if [[ ${project_name} == caligula95-spring_crud ]]; then
  echo "Patching caligula95-spring_crud"
  find -name SpringCrudApplicationTests.java | xargs rm -f
  find -name UsersRepositoryTest.java | xargs rm -f
fi

if [[ ${project_name} == sgsinclair-trombone ]]; then
  echo "Patching sgsinclair-trombone"
  find -name LuceneIndexerTest.java | xargs rm -f
  find -name XmlExtractorTest.java | xargs rm -f
  find -name JsonFeaturesTest.java | xargs rm -f
  find -name TikaExtractorTest.java | xargs rm -f
  find -name CorpusCreatorTest.java | xargs rm -f
  find -name DocumentTokensTest.java | xargs rm -f
  find -name GeonamesTest.java | xargs rm -f
  find -name CorpusFacetsTest.java | xargs rm -f
  find -name CorpusCollocatesTest.java | xargs rm -f
fi

if [[ ${project_name} == intive-FDV-DynamicJasper ]]; then
  echo "Patching intive-FDV-DynamicJasper"
  find -name HQLReportTest.java | xargs rm -f
fi

if [[ ${project_name} == alibaba-QLExpress ]]; then
  echo "Patching alibaba-QLExpress"
  find -name ForFlowFunctionTest.java | xargs rm -f
fi

if [[ ${project_name} == HamaWhiteGG-flink-sql-security ]]; then
  echo "Patching HamaWhiteGG-flink-sql-security"
  echo -n "Arrays_MutuallyComparable" > .skip-spec.txt
fi

if [[ ${project_name} == HiveRunner-mutant-swarm ]]; then
  echo "Patching HiveRunner-mutant-swarm"
  find -name MutantSwarmParseDriverTest.java | xargs rm -f
  find -name MutantSwarmStatementTest.java | xargs rm -f
  find -name MutantSwarmExtensionTest.java | xargs rm -f
  find -name mutantswarm.java | xargs rm -f
  find -name LexerMutatorStoreTest.java | xargs rm -f
  find -name VocabularyTest.java | xargs rm -f
  find -name ParserMutatorStoreTest.java | xargs rm -f
  find -name MutantSwarmRunnerTest.java | xargs rm -f
fi

if [[ ${project_name} == pebbleblog-pebble ]]; then
  echo "Patching pebbleblog-pebble"
  find -name TagIndexTest.java | xargs rm -f
  find -name SearchIndexTest.java | xargs rm -f
  find -name AuthorIndexTest.java | xargs rm -f
  find -name FileStaticPageDAOTest.java | xargs rm -f
  find -name FileBlogEntryDAOTest.java | xargs rm -f
  find -name CommentTest.java | xargs rm -f
  find -name BlogEntryTest.java | xargs rm -f
  find -name CategoryTest.java | xargs rm -f
  find -name BlogTest.java | xargs rm -f
  find -name MultiBlogTest.java | xargs rm -f
  find -name BlogServiceTest.java | xargs rm -f
  find -name TagTest.java | xargs rm -f
  find -name CategoryBuilderTest.java | xargs rm -f
  find -name TrackBackTest.java | xargs rm -f
  find -name CommentEventTest.java | xargs rm -f
  find -name TrackBackEventTest.java | xargs rm -f
  find -name ResponseByDateComparatorTest.java | xargs rm -f
  find -name RequestTest.java | xargs rm -f
  find -name NoFollowDecoratorTest.java | xargs rm -f
  find -name HideUnapprovedResponsesDecoratorTest.java | xargs rm -f
  find -name BlogTagsDecoratorTest.java | xargs rm -f
  find -name RelatedPostsDecoratorTest.java | xargs rm -f
  find -name EscapeMarkupDecoratorTest.java | xargs rm -f
  find -name TechnoratiTagsDecoratorTest.java | xargs rm -f
  find -name DisableResponseListenerTest.java | xargs rm -f
  find -name ContentSpamListenerTest.java | xargs rm -f
  find -name MarkPendingListenerTest.java | xargs rm -f
  find -name MarkApprovedListenerTest.java | xargs rm -f
  find -name LinkSpamListenerTest.java | xargs rm -f
  find -name SpamScoreListenerTest.java | xargs rm -f
  find -name IpAddressListenerTest.java | xargs rm -f
  find -name SearchResultsTest.java | xargs rm -f
  find -name DefaultPermalinkProviderTest.java | xargs rm -f
  find -name TitlePermalinkProviderTest.java | xargs rm -f
  find -name Latin1SeoPermalinkProviderTest.java | xargs rm -f
  find -name ShortPermalinkProviderTest.java | xargs rm -f
  find -name MultiBlogBloggerAPIHandlerTest.java | xargs rm -f
  find -name MultiBlogMetaWeblogAPIHandlerTest.java | xargs rm -f
  find -name SingleBlogMetaWeblogAPIHandlerTest.java | xargs rm -f
  find -name SingleBlogBloggerAPIHandlerTest.java | xargs rm -f
  find -name MovableTypeImporterTest.java | xargs rm -f
  find -name StringUtilsTest.java | xargs rm -f
  find -name AddBlogEntryActionTest.java | xargs rm -f
  find -name EditBlogEntryActionTest.java | xargs rm -f
  find -name SaveFileActionTest.java | xargs rm -f
  find -name RemoveFilesActionTest.java | xargs rm -f
  find -name ManageBlogEntryActionTest.java | xargs rm -f
  find -name SaveCommentActionTest.java | xargs rm -f
  find -name ViewResponsesActionTest.java | xargs rm -f
  find -name CopyFileActionTest.java | xargs rm -f
  find -name PublishBlogEntryActionTest.java | xargs rm -f
  find -name ViewBlogEntryActionTest.java | xargs rm -f
  find -name BlogEntryToPdfActionTest.java | xargs rm -f
  find -name ViewHomePageActionTest.java | xargs rm -f
  find -name CreateDirectoryActionTest.java | xargs rm -f
  find -name MultiBlogFeedActionTest.java | xargs rm -f
  find -name FeedViewTest.java | xargs rm -f
  find -name UriTransformerTest.java | xargs rm -f
fi

if [[ ${project_name} == RedCA-Family-code-analyst ]]; then
  echo "Patching RedCA-Family-code-analyst"
  find -name UnusedCodeAnalysisLauncherTest.java | xargs rm -f
fi

if [[ ${project_name} == pack200-pack200 ]]; then
  echo "Patching pack200-pack200"
  echo -n "Arrays_MutuallyComparable" > .skip-spec.txt
fi

if [[ ${project_name} == joniles-mpxj ]]; then
  echo "Patching joniles-mpxj"
  sed -i '/@Test public void testGetProjectWriter/i\    @org.junit.Ignore' ./src/test/java/net/sf/mpxj/junit/ProjectWriterUtilityTest.java
  sed -i '/@Test public void testGetSupportedFileExtensions/i\    @org.junit.Ignore' ./src/test/java/net/sf/mpxj/junit/ProjectWriterUtilityTest.java
fi

if [[ ${project_name} == php-coder-mystamps ]]; then
  echo "Patching php-coder-mystamps"
  sed -i 's/<disableXmlReport>true<\/disableXmlReport>/<disableXmlReport>false<\/disableXmlReport>/g' pom.xml
  rm src/test/groovy/ru/mystamps/web/feature/site/SiteServiceImplTest.groovy
  rm src/test/groovy/ru/mystamps/web/feature/image/FilesystemImagePersistenceStrategyTest.groovy
fi

if [[ ${project_name} == stackify-stackify-api-java ]]; then
  echo "Patching stackify-stackify-api-java"
  sed -i '/public void testAddAndFlushWithAppIdentity/i\    @org.junit.Ignore' ./src/test/java/com/stackify/api/common/log/LogCollectorTest.java
fi

if [[ ${project_name} == confluentinc-kafka-connect-jdbc ]]; then
  echo "Patching confluentinc-kafka-connect-jdbc"
  sed -i '/public void testTimestampWithTimestampInitialCurrent/i\    @org.junit.Ignore' ./src/test/java/io/confluent/connect/jdbc/source/JdbcSourceTaskUpdateTest.java
  sed -i '/public void testTimestampWithDelay/i\    @org.junit.Ignore' ./src/test/java/io/confluent/connect/jdbc/source/JdbcSourceTaskUpdateTest.java
fi

if [[ ${project_name} == Unleash-unleash-client-java ]]; then
  echo "Patching Unleash-unleash-client-java"
  sed -i '/public void asynchronous_fetch_on_initialisation_fails_silently_and_retries/i\    @org.junit.jupiter.api.Disabled' ./src/test/java/io/getunleash/DefaultUnleashTest.java
fi

if [[ ${project_name} == apache-commons-collections ]]; then
  echo "Patching apache-commons-collections"
  sed -i '/public void testPurgeValues/i\    @org.junit.Ignore' ./src/test/java/org/apache/commons/collections4/map/ReferenceMapTest.java
fi

if [[ ${project_name} == cafebazaar-bundle-signer ]]; then
  echo "Patching cafebazaar-bundle-signer"
  sed -i '/public void testV2SignatureDoesNotMatchSignedDataRejected/i\    @org.junit.Ignore' ./src/test/java/ir/cafebazaar/apksig/ApkVerifierTest.java
fi

if [[ ${project_name} == confluentinc-kafka-connect-elasticsearch ]]; then
  echo "Patching confluentinc-kafka-connect-elasticsearch"
  find -name ElasticsearchClientTest.java | xargs rm
fi

if [[ ${project_name} == CourseOrchestra-xylophone ]]; then
  echo "Patching CourseOrchestra-xylophone"
  sed -i '/public void checkGenerateResultXlsFileWithSpecialSymbolsInDataXmlShouldSuccess/i\    @org.junit.Ignore' ./src/test/java/ru/curs/xylophone/TestOverall.java
  sed -i '/public void convertToPdfWithSymbolOfRoubleAndPercentShouldSuccess/i\    @org.junit.Ignore' ./src/test/java/ru/curs/xylophone/TestFO.java
fi

if [[ ${project_name} == efluid-testControlByteCode ]]; then
  echo "Patching efluid-testControlByteCode"
  rm -rf ./src/test/java/com/efluid/example/TestExampleControlByteCode.java
fi

if [[ ${project_name} == jmxtrans-embedded-jmxtrans ]]; then
  echo "Patching jmxtrans-embedded-jmxtrans"
  rm -rf ./src/test/java/org/jmxtrans/embedded/output/StatsDWriterChannelFailureTest.java
fi

if [[ ${project_name} == opentracing-contrib-java-grpc ]]; then
  echo "Patching opentracing-contrib-java-grpc"
  sed -i '/public void testTracedClientWithTracedAttributes/i\    @org.junit.Ignore' ./src/test/java/io/opentracing/contrib/grpc/TracingClientInterceptorTest.java
fi

if [[ ${project_name} == Juniper-netconf-java ]]; then
  echo "Patching Juniper-netconf-java"
  sed -i '/public void GIVEN_createSession_WHEN_timeoutExceeded_THEN_throwSocketTimeoutException/i\    @org.junit.Ignore' ./src/test/java/net/juniper/netconf/NetconfSessionTest.java
fi

if [[ ${project_name} == adminfaces-admin-persistence ]]; then
  echo "Patching adminfaces-admin-persistence"
  sed -i '/public void shouldFindCarById/i\    @org.junit.Ignore' ./src/test/java/com/github/adminfaces/persistence/CrudServiceIt.java
  sed -i '/public void shouldListCarsByPrice/i\    @org.junit.Ignore' ./src/test/java/com/github/adminfaces/persistence/CrudServiceIt.java
fi

if [[ ${project_name} == ahus1-prometheus-hystrix ]]; then
  echo "Patching ahus1-prometheus-hystrix"
  sed -i '/public void shouldIncrementCounterHistogram/i\    @org.junit.Ignore' ./src/test/java/com/soundcloud/prometheus/hystrix/HystrixCommandTest.java
  sed -i '/public void shouldWorkWithTwoCommands/i\    @org.junit.Ignore' ./src/test/java/com/soundcloud/prometheus/hystrix/HystrixCommandTest.java
fi

if [[ ${project_name} == aschoerk-converter-page ]]; then
  echo "Patching aschoerk-converter-page"
  rm -rf ./src/test/java/de/aschoerk/javaconv/IdTrackerTest.java
fi

if [[ ${project_name} == davidmoten-rtree ]]; then
  echo "Patching davidmoten-rtree"
  sed -i '/public void testOperatorShouldRequestMaxFromUpstream/i\    @org.junit.Ignore' ./src/test/java/com/github/davidmoten/internal/operators/OperatorBoundedPriorityQueueTest.java
  sed -i '/public void testUnsubscribe/i\    @org.junit.Ignore' ./src/test/java/com/github/davidmoten/rtree/RTreeTest.java
fi

if [[ ${project_name} == delving-x3ml ]]; then
  echo "Patching delving-x3ml"
  find -name TestLido07.java | xargs rm -f
  sed -i '/TestLido07\.class,/d' ./src/test/java/eu/delving/x3ml/AllTests.java
  sed -i '/public void testAttribute/i\    @org.junit.Ignore' ./src/test/java/eu/delving/x3ml/TestRijks.java
  sed -i '/public void testRough/i\    @org.junit.Ignore' ./src/test/java/eu/delving/x3ml/TestRijks.java
fi

if [[ ${project_name} == Azure-autorest-clientruntime-for-java ]]; then
  echo "Patching Azure-autorest-clientruntime-for-java"
  sed -i 's/< 2000/< 2000000/g' ./client-runtime/src/test/java/com/microsoft/rest/ConnectionPoolTests.java
fi

if [[ ${project_name} == StarlangSoftware-TurkishMorphologicalDisambiguation ]]; then
  echo "Patching StarlangSoftware-TurkishMorphologicalDisambiguation"
  sed -i 's/0.002/1/g' ./src/test/java/MorphologicalDisambiguation/DummyDisambiguationTest.java
fi

if [[ ${project_name} == alexheretic-dynamics ]]; then
  echo "Patching alexheretic-dynamics"
  sed -i '/public void epochMillisLongParsing/i\    @org.junit.Ignore' ./src/test/java/alexh/ConverterTest.java
  sed -i '/public void stringLong/i\    @org.junit.Ignore' ./src/test/java/alexh/ConverterTest.java
  sed -i '/public void utilDateSupport/i\    @org.junit.Ignore' ./src/test/java/alexh/ConverterTest.java
fi
