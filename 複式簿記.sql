DROP DATABASE IF EXISTS 複式簿記;
CREATE DATABASE 複式簿記;
USE 複式簿記;

CREATE TABLE 仕訳帳 (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,

    日付         DATE,
    借方勘定科目 VARCHAR(8),
    借方金額     DECIMAL(10,0),
    貸方勘定科目 VARCHAR(8),
    貸方金額     DECIMAL(10,0),
    摘要         VARCHAR(255),
    備考         VARCHAR(8)
);

CREATE TABLE 勘定科目マスタ (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,

    科目名   VARCHAR(8),
    貸借区分 VARCHAR(2),
    精算表   VARCHAR(5)
);


CREATE VIEW 総勘定元帳 AS
SELECT 仕訳帳.id AS 仕訳帳_id,
       仕訳帳.日付 AS 日付,
       仕訳帳.借方勘定科目 AS 勘定科目,
       仕訳帳.貸方勘定科目 AS 相手勘定科目,
       仕訳帳.摘要 AS 摘要,
       仕訳帳.借方金額 AS 借方金額,
       0 AS 貸方金額,
       仕訳帳.備考 AS 備考
FROM 仕訳帳
UNION
SELECT 仕訳帳.id AS 仕訳帳_id,
       仕訳帳.日付 AS 日付,
       仕訳帳.貸方勘定科目 AS 勘定科目,
       仕訳帳.借方勘定科目 AS 相手勘定科目,
       仕訳帳.摘要 AS 摘要,
       0 AS 借方金額,
       仕訳帳.貸方金額 AS 貸方金額,
       仕訳帳.備考 AS 備考
FROM 仕訳帳;

CREATE VIEW 総勘定元帳_残高付き AS
SELECT A.仕訳帳_id AS 仕訳帳_id,
       A.日付 AS 日付,
       A.勘定科目 AS 勘定科目,
       A.相手勘定科目 AS 相手勘定科目,
       A.摘要 AS 摘要,
       A.借方金額 AS 借方金額,
       A.貸方金額 AS 貸方金額,
       CASE WHEN 勘定科目マスタ.貸借区分 = '借方'
            THEN SUM(B.借方金額 - B.貸方金額)
            ELSE SUM(B.貸方金額 - B.借方金額) END AS 残高,
       A.備考 AS 備考
FROM 総勘定元帳 AS A
JOIN 総勘定元帳 AS B ON A.勘定科目 = B.勘定科目 AND A.仕訳帳_id >= B.仕訳帳_id
JOIN 勘定科目マスタ ON A.勘定科目 = 勘定科目マスタ.科目名
GROUP BY A.仕訳帳_id,
         A.日付,
         A.勘定科目,
         A.相手勘定科目,
         A.摘要,
         A.借方金額,
         A.貸方金額,
         A.備考
ORDER BY 勘定科目, 仕訳帳_id;


CREATE VIEW 試算表 AS
SELECT 総勘定元帳.勘定科目 AS 勘定科目,
       SUM(総勘定元帳.借方金額) AS 借方合計,
       SUM(総勘定元帳.貸方金額) AS 貸方合計,
       CASE WHEN 勘定科目マスタ.貸借区分 = '借方'
            THEN SUM(総勘定元帳.借方金額 - 総勘定元帳.貸方金額)
            ELSE 0 END AS 借方残高,
       CASE WHEN 勘定科目マスタ.貸借区分 = '貸方'
            THEN SUM(総勘定元帳.貸方金額 - 総勘定元帳.借方金額)
            ELSE 0 END AS 貸方残高
FROM 総勘定元帳
JOIN 勘定科目マスタ ON 総勘定元帳.勘定科目 = 勘定科目マスタ.科目名
WHERE 総勘定元帳.備考 != '決算整理'
GROUP BY 勘定科目
ORDER BY 勘定科目マスタ.id;

CREATE VIEW 試算表計 AS
SELECT '計',
       SUM(借方合計) AS 借方合計,
       SUM(貸方合計) AS 貸方合計,
       SUM(借方残高) AS 借方残高,
       SUM(貸方残高) AS 貸方残高
FROM 試算表;


CREATE VIEW 整理記入 AS
SELECT 総勘定元帳.勘定科目 AS 勘定科目,
       SUM(総勘定元帳.借方金額) AS 借方合計,
       SUM(総勘定元帳.貸方金額) AS 貸方合計
FROM 総勘定元帳
JOIN 勘定科目マスタ ON 総勘定元帳.勘定科目 = 勘定科目マスタ.科目名
WHERE 総勘定元帳.備考 = '決算整理'
GROUP BY 勘定科目;


CREATE VIEW 損益計算書 AS
SELECT 勘定科目マスタ.科目名 AS 勘定科目,
       CASE WHEN 勘定科目マスタ.貸借区分 = '借方'
            THEN IFNULL(試算表.借方合計, 0) - IFNULL(試算表.貸方合計, 0)
               + IFNULL(整理記入.借方合計, 0) - IFNULL(整理記入.貸方合計, 0)
            ELSE 0 END AS 借方合計,
       CASE WHEN 勘定科目マスタ.貸借区分 = '貸方'
            THEN IFNULL(試算表.貸方合計, 0) - IFNULL(試算表.借方合計, 0)
               + IFNULL(整理記入.貸方合計, 0) - IFNULL(整理記入.借方合計, 0)
            ELSE 0 END AS 貸方合計
FROM 勘定科目マスタ
LEFT JOIN 試算表 ON 勘定科目マスタ.科目名 = 試算表.勘定科目
LEFT JOIN 整理記入 ON 勘定科目マスタ.科目名 = 整理記入.勘定科目
WHERE 勘定科目マスタ.精算表 = '損益計算書';


CREATE VIEW 貸借対照表 AS
SELECT 勘定科目マスタ.科目名 AS 勘定科目,
       CASE WHEN 勘定科目マスタ.貸借区分 = '借方'
            THEN IFNULL(試算表.借方合計, 0) - IFNULL(試算表.貸方合計, 0)
               + IFNULL(整理記入.借方合計, 0) - IFNULL(整理記入.貸方合計, 0)
            ELSE 0 END AS 借方合計,
       CASE WHEN 勘定科目マスタ.貸借区分 = '貸方'
            THEN IFNULL(試算表.貸方合計, 0) - IFNULL(試算表.借方合計, 0)
               + IFNULL(整理記入.貸方合計, 0) - IFNULL(整理記入.借方合計, 0)
            ELSE 0 END AS 貸方合計
FROM 勘定科目マスタ
LEFT JOIN 試算表 ON 勘定科目マスタ.科目名 = 試算表.勘定科目
LEFT JOIN 整理記入 ON 勘定科目マスタ.科目名 = 整理記入.勘定科目
WHERE 勘定科目マスタ.精算表 = '貸借対照表';


CREATE VIEW 精算表 AS
SELECT 勘定科目マスタ.科目名 AS 勘定科目,
       IFNULL(試算表.借方残高, 0) AS 試算表借方,
       IFNULL(試算表.貸方残高, 0) AS 試算表貸方,
       IFNULL(整理記入.借方合計, 0) AS 整理記入借方,
       IFNULL(整理記入.貸方合計, 0) AS 整理記入貸方,
       IFNULL(損益計算書.借方合計, 0) AS 損益計算書借方,
       IFNULL(損益計算書.貸方合計, 0) AS 損益計算書貸方,
       IFNULL(貸借対照表.借方合計, 0) AS 貸借対照表借方,
       IFNULL(貸借対照表.貸方合計, 0) AS 貸借対照表貸方
FROM 勘定科目マスタ
LEFT JOIN 試算表 ON 勘定科目マスタ.科目名 = 試算表.勘定科目
LEFT JOIN 整理記入 ON 勘定科目マスタ.科目名 = 整理記入.勘定科目
LEFT JOIN 損益計算書 ON 勘定科目マスタ.科目名 = 損益計算書.勘定科目
LEFT JOIN 貸借対照表 ON 勘定科目マスタ.科目名 = 貸借対照表.勘定科目;
        
CREATE VIEW 当期純利益 AS
SELECT '当期純利益',
       0,0,0,0,
       SUM(貸方合計 - 借方合計),
       0,0,
       SUM(貸方合計 - 借方合計)
FROM 損益計算書;

CREATE VIEW 精算表＋当期純利益 AS
SELECT * FROM 精算表 UNION
SELECT * FROM 当期純利益;

CREATE VIEW 精算表計 AS
SELECT '計',
       SUM(試算表借方) AS 試算表借方,
       SUM(試算表貸方) AS 試算表貸方,
       SUM(整理記入借方) AS 整理記入借方,
       SUM(整理記入貸方) AS 整理記入貸方,
       SUM(損益計算書借方) AS 損益計算書借方,
       SUM(損益計算書貸方) AS 損益計算書貸方,
       SUM(貸借対照表借方) AS 貸借対照表借方,
       SUM(貸借対照表貸方) AS 貸借対照表貸方
FROM 精算表＋当期純利益;


CREATE VIEW 仕訳帳_印刷用 AS
SELECT * FROM 仕訳帳;

DELIMITER //
CREATE PROCEDURE 科目ごと総勘定元帳作成()
BEGIN
    DECLARE account_title VARCHAR(8);
    DECLARE _cursor CURSOR FOR SELECT 科目名 FROM 勘定科目マスタ;
    
    SET @idx = 0;
    SELECT COUNT(*) INTO @count FROM 勘定科目マスタ;
    OPEN _cursor;

    WHILE @idx < @count DO
        FETCH _cursor INTO account_title;

        SELECT CONCAT('CREATE VIEW 総勘定元帳_', account_title,'_印刷用 AS
                       SELECT 仕訳帳_id,
                              日付,
                              相手勘定科目,
                              摘要,
                              借方金額,
                              貸方金額,
                              残高,
                              備考
                       FROM 総勘定元帳_残高付き
                       WHERE 勘定科目 = "', account_title, '"
                       ORDER BY 仕訳帳_id') INTO @s;

        PREPARE stmt FROM @s;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SET @idx = @idx + 1;
    END WHILE;

    CLOSE _cursor;
END

//
DELIMITER ;

CREATE VIEW 試算表_印刷用 AS
SELECT * FROM 試算表 UNION
SELECT * FROM 試算表計;

CREATE VIEW 精算表_印刷用 AS
SELECT * FROM 精算表 UNION
SELECT * FROM 当期純利益 UNION
SELECT * FROM 精算表計;


LOAD DATA LOCAL INFILE '仕訳帳.csv'
    INTO TABLE 仕訳帳
    FIELDS TERMINATED BY ','
    LINES TERMINATED BY '\n'
    (@date, 借方勘定科目, 借方金額, 貸方勘定科目, 貸方金額, 摘要, @remarks)
    SET 日付 = STR_TO_DATE(@date, '%Y-%m-%d'),
        備考 = IF(@remarks IS NOT NULL, @remarks, '');

LOAD DATA LOCAL INFILE '勘定科目マスタ.csv'
    INTO TABLE 勘定科目マスタ
    FIELDS TERMINATED BY ','
    LINES TERMINATED BY '\n'
    (科目名, 貸借区分, 精算表);

CALL 科目ごと総勘定元帳作成;
