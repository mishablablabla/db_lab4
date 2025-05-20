-- ====================================================
-- Завдання 3 (1). Скалярні функції
-- ====================================================
CREATE FUNCTION dbo.fn_TotalPairsPerTeacherDay
(
    @teacher_id INT,
    @day_of_week NVARCHAR(15) = NULL
)
RETURNS INT
AS
BEGIN
    DECLARE @result INT;

    SELECT @result = COUNT(*) 
    FROM Schedule
    WHERE teacher_id = @teacher_id
      AND (@day_of_week IS NULL OR day_of_week = @day_of_week);

    RETURN @result;
END;


-- Завдання 3 (2).
CREATE FUNCTION dbo.fn_TotalPairsPerGroupWeek
(
    @group_id INT
)
RETURNS INT
AS
BEGIN
    DECLARE @total INT;

    SELECT @total = COUNT(*)
    FROM Schedule
    WHERE group_id = @group_id;

    RETURN @total;
END;


-- Завдання 3 (3).
CREATE FUNCTION dbo.fn_IsLectureRoomFree
(
    @auditorium_id INT,
    @day NVARCHAR(15),
    @pair INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @result BIT;

    IF EXISTS (
        SELECT 1
        FROM Schedule
        WHERE auditorium_id = @auditorium_id
          AND day_of_week = @day
          AND pair_number = @pair
    )
        SET @result = 0;  
    ELSE
        SET @result = 1;  

    RETURN @result;
END;



SELECT dbo.fn_TotalPairsPerTeacherDay(2, NULL);
SELECT dbo.fn_TotalPairsPerTeacherDay(2, 'Wednesday');

SELECT dbo.fn_TotalPairsPerGroupWeek(8);

SELECT dbo.fn_IsLectureRoomFree(5,'Wednesday', 2);


-- ====================================================
-- Завдання 4. Inline тип функцій
-- ====================================================

-- Функція 1: Розклад для заданої групи
CREATE FUNCTION dbo.fn_ScheduleForGroup
(
    @group_id INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        day_of_week,
        pair_number,
        Teachers.full_name AS teacher_name,
        Subjects.name AS subject_name,
        Auditoriums.room_number,
        Auditoriums.building,
        CASE day_of_week
            WHEN 'Monday' THEN 1
            WHEN 'Tuesday' THEN 2
            WHEN 'Wednesday' THEN 3
            WHEN 'Thursday' THEN 4
            WHEN 'Friday' THEN 5
            WHEN 'Saturday' THEN 6
            ELSE 7
        END AS day_order
    FROM Schedule
    JOIN Teachers ON Schedule.teacher_id = Teachers.id
    JOIN Subjects ON Schedule.subject_id = Subjects.id
    JOIN Auditoriums ON Schedule.auditorium_id = Auditoriums.id
    WHERE group_id = @group_id
);

-- Функція 2: Розклад викладача за академічною ступеню
CREATE FUNCTION dbo.fn_ScheduleForTeacherDegree
(
    @degree NVARCHAR(50)
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        day_of_week,
        pair_number,
        Groups.group_number,
        Subjects.name AS subject_name,
        Auditoriums.room_number
    FROM Schedule
    JOIN Teachers ON Schedule.teacher_id = Teachers.id
    JOIN Groups ON Schedule.group_id = Groups.id
    JOIN Subjects ON Schedule.subject_id = Subjects.id
    JOIN Auditoriums ON Schedule.auditorium_id = Auditoriums.id
    WHERE Teachers.academic_degree = @degree
);

-- Функція 3: Свободні аудиторії певного типу у вказаний день і пару
CREATE FUNCTION dbo.fn_FreeAuditoriums
(
    @day NVARCHAR(15),
    @pair INT,
    @aud_type NVARCHAR(50)
)
RETURNS TABLE
AS
RETURN
(
    SELECT id, room_number, building
    FROM Auditoriums
    WHERE type = @aud_type
    AND id NOT IN (
        SELECT auditorium_id 
        FROM Schedule
        WHERE day_of_week = @day
          AND pair_number = @pair
    )
);



SELECT * FROM dbo.fn_ScheduleForGroup(1)
ORDER BY day_order, pair_number;

SELECT * FROM dbo.fn_ScheduleForTeacherDegree(N'PhD')
ORDER BY day_of_week, pair_number;

SELECT * FROM dbo.fn_FreeAuditoriums(N'Monday', 2, N'Lecture')
ORDER BY room_number;


-- ====================================================
-- Завдання 5. Multistate тип функцій (Table-Valued Functions)
-- ====================================================

-- Функція 1: Розклад для викладача на заданий день
CREATE FUNCTION dbo.fn_ScheduleForTeacherDay
(
    @teacher_id INT,
    @day NVARCHAR(15)
)
RETURNS @Schedule TABLE
(
    pair_number INT,
    group_number VARCHAR(10),
    subject_name VARCHAR(100),
    auditorium_room VARCHAR(10)
)
AS
BEGIN
    INSERT INTO @Schedule
    SELECT 
        s.pair_number,
        g.group_number,
        sub.name,
        a.room_number
    FROM Schedule s
    JOIN Groups g ON s.group_id = g.id
    JOIN Subjects sub ON s.subject_id = sub.id
    JOIN Auditoriums a ON s.auditorium_id = a.id
    WHERE s.teacher_id = @teacher_id AND s.day_of_week = @day
    ORDER BY s.pair_number;

    RETURN;
END;

-- Функція 2: Список груп, які мають заняття у певній аудиторії в певний день
CREATE FUNCTION dbo.fn_GroupsInAuditoriumDay
(
    @auditorium_id INT,
    @day NVARCHAR(15)
)
RETURNS @Groups TABLE
(
    group_number VARCHAR(10),
    pair_number INT,
    subject_name VARCHAR(100)
)
AS
BEGIN
    INSERT INTO @Groups
    SELECT 
        g.group_number,
        s.pair_number,
        sub.name
    FROM Schedule s
    JOIN Groups g ON s.group_id = g.id
    JOIN Subjects sub ON s.subject_id = sub.id
    WHERE s.auditorium_id = @auditorium_id AND s.day_of_week = @day
    ORDER BY s.pair_number;

    RETURN;
END;

-- Функція 3: Викладачі, які можуть вести заданий предмет
CREATE FUNCTION dbo.fn_TeachersBySubject
(
    @subject_name VARCHAR(100)
)
RETURNS @Teachers TABLE
(
    teacher_name VARCHAR(100),
    academic_degree VARCHAR(50),
    department VARCHAR(100)
)
AS
BEGIN
    INSERT INTO @Teachers
    SELECT 
        t.full_name,
        t.academic_degree,
        t.department
    FROM Teachers t
    WHERE CHARINDEX(@subject_name, t.teaching_types) > 0;

    RETURN;
END;


SELECT * FROM dbo.fn_ScheduleForTeacherDay(1, 'Monday');

SELECT * FROM dbo.fn_GroupsInAuditoriumDay(2, 'Tuesday');

SELECT * FROM dbo.fn_TeachersBySubject('Lecture')




-- ====================================================
-- Завдання 6. Виконання запитів за тематикою варіанту
-- ====================================================

-- 1. Скалярна функція: загальна кількість пар за тиждень для групи
CREATE FUNCTION dbo.fn_TotalPairsPerGrouspWeek
(
    @group_id INT
)
RETURNS INT
AS
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM Schedule
        WHERE group_id = @group_id
    );
END;

-- 2. Inline table-valued функція: розклад викладачів з певною науковою степеню
CREATE FUNCTION dbo.fn_ScheduleForTeachersByDegree
(
    @academic_degree NVARCHAR(50)
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        t.full_name,
        s.day_of_week,
        s.pair_number,
        g.group_number,
        sub.name AS subject_name,
        a.room_number
    FROM Schedule s
    JOIN Teachers t ON s.teacher_id = t.id
    JOIN Groups g ON s.group_id = g.id
    JOIN Subjects sub ON s.subject_id = sub.id
    JOIN Auditoriums a ON s.auditorium_id = a.id
    WHERE t.academic_degree = @academic_degree
);

-- 3. Multistate table-valued функція: пошук вільних викладачів для предмету на певний день і пару
CREATE FUNCTION dbo.fn_AvailableTeachersForSubject
(
    @subject_name NVARCHAR(100),
    @day_of_week NVARCHAR(15),
    @pair_number INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT t.id, t.full_name, t.academic_degree, t.department
    FROM Teachers t
    WHERE CHARINDEX(@subject_name, t.teaching_types) > 0
      AND NOT EXISTS (
        SELECT 1 FROM Schedule s
        WHERE s.teacher_id = t.id
          AND s.day_of_week = @day_of_week
          AND s.pair_number = @pair_number
      )
);


SELECT dbo.fn_TotalPairsPerGrouspWeek(8);

SELECT * FROM dbo.fn_ScheduleForTeachersByDegree('Doctor of Sciences');

SELECT * FROM dbo.fn_AvailableTeachersForSubject('Lecture', 'Tuesday', 2);


