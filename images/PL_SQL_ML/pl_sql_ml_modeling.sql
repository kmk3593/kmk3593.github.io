-- 의사 결정 트리 모델로 퇴사자 예측 모델 만들기
-- 데이터셋 : https://www.kaggle.com/datasets/pankeshpatel/hrcommasep
-- 기존에 있을지도 모를 HR 데이터 삭제
-- 퇴사 여부 예측 (LEFT)

SELECT COUNT(*) FROM HR_DATA_MAIN;
-- 14999

-- 훈련 데이터와 테스트 데이터로 분리
DROP TABLE HR_DATA_TRAINING; 
CREATE TABLE HR_DATA_TRAINING
AS
   SELECT *
     FROM HR_DATA_MAIN
     WHERE EMP_ID < 10500;

DROP TABLE HR_DATA_TEST;

CREATE TABLE HR_DATA_TEST
AS
   SELECT *
     FROM HR_DATA_MAIN
     WHERE EMP_ID >= 10500;

-- 머신 러닝 모델의 환경설정을 위한 정보가 들어있는 테이블을 생성합니다. 
-- URL : https://docs.oracle.com/database/121/ARPLS/d_datmin.htm#ARPLS192
DROP TABLE DTSETTINGS;
CREATE TABLE DTSETTINGS
AS
SELECT *
  FROM TABLE (DBMS_DATA_MINING.GET_DEFAULT_SETTINGS)
  WHERE SETTING_NAME LIKE '%GLM%';

BEGIN
  INSERT INTO DTSETTINGS
    VALUES ('ALGO_NAME', 'ALGO_DECISION_TREE');

  INSERT INTO DTSETTINGS
     VALUES (DBMS_DATA_MINING.TREE_IMPURITY_METRIC, 'TREE_IMPURITY_ENTROPY'); -- 모델의 핵심엔진은 엔트로피로 설정
COMMIT;
END;
/

-- 머신 러닝 모델을 생성합니다.
BEGIN
  DBMS_DATA_MINING.DROP_MODEL('DT_MODEL');
END;
/

BEGIN
   DBMS_DATA_MINING.CREATE_MODEL (
      MODEL_NAME            => 'DT_MODEL',
      MINING_FUNCTION       => DBMS_DATA_MINING.CLASSIFICATION,
      DATA_TABLE_NAME       => 'HR_DATA_TRAINING',
      CASE_ID_COLUMN_NAME   => 'EMP_ID',
      TARGET_COLUMN_NAME    => 'LEFT',
      SETTINGS_TABLE_NAME   => 'DTSETTINGS');
END;
/

-- 5. 생성된 모델을 확인합니다.
SELECT MODEL_NAME,
          ALGORITHM,
          MINING_FUNCTION
  FROM ALL_MINING_MODELS
  WHERE MODEL_NAME = 'DT_MODEL';

-- 6. 생성된 모델의 환경설정 내용을 확인합니다. 
SELECT SETTING_NAME, SETTING_VALUE
  FROM ALL_MINING_MODEL_SETTINGS
  WHERE MODEL_NAME = 'DT_MODEL';

-- 7. 실제 값과 예측 값과 예측 확률을 출력합니다. 
SELECT EMP_ID, T.LEFT 실제값,
          PREDICTION (DT_MODEL USING *) 예측값,
          PREDICTION_PROBABILITY (DT_MODEL USING *) "모델이 예측한 확률"
  FROM HR_DATA_TEST T;

-- 8. 학습한 머신러닝 모델의 성능을 확인합니다.
DROP TABLE HR_DATA_TEST_MATRIX_2;
CREATE OR REPLACE VIEW   VIEW_HR_DATA_TEST
AS
SELECT EMP_ID, PREDICTION(DT_MODEL USING *) PREDICTED_VALUE,
          PREDICTION_PROBABILITY(DT_MODEL USING * ) PROBABILITY
  FROM HR_DATA_TEST;
  
SET SERVEROUTPUT ON 

DECLARE
   V_ACCURACY NUMBER;
BEGIN
   DBMS_DATA_MINING.COMPUTE_CONFUSION_MATRIX (
      ACCURACY           => V_ACCURACY,
      APPLY_RESULT_TABLE_NAME      => 'VIEW_HR_DATA_TEST',
      TARGET_TABLE_NAME       => 'HR_DATA_TEST',
      CASE_ID_COLUMN_NAME       => 'EMP_ID',
      TARGET_COLUMN_NAME       => 'LEFT',
      CONFUSION_MATRIX_TABLE_NAME => 'HR_DATA_TEST_MATRIX_2',
      SCORE_COLUMN_NAME       => 'PREDICTED_VALUE',
      SCORE_CRITERION_COLUMN_NAME => 'PROBABILITY',
      COST_MATRIX_TABLE_NAME      => NULL,
      APPLY_RESULT_SCHEMA_NAME    => NULL,
      TARGET_SCHEMA_NAME       => NULL,
      COST_MATRIX_SCHEMA_NAME     => NULL,
      SCORE_CRITERION_TYPE       => 'PROBABILITY');
   DBMS_OUTPUT.PUT_LINE('**** MODEL ACCURACY ****: ' || ROUND(V_ACCURACY,4));
END;
/

