#!/bin/bash
# shellcheck disable=SC2317																			# Don't warn about unreachable commands in this file

# abstet18+.bash   version 0.1, © 2024 by Sergey Vasiliev aka abs.
# abstet18+.bash - Tetris 18+ in the Linux terminal / Тетрис 18+ в окне терминала.
# 
# abstet18+.bash comes with ABSOLUTELY NO WARRANTY. This is free software, and you are welcome to redistribute it under certain conditions. See the GNU General Public Licence for details.
# 
# Использование:
#   вариант 1:   abstet18+.bash [ОПЦИЯ] ...
#   вариант 2: . abstet18+.bash [ОПЦИЯ] ...  - запуск в текущей оболочке (см. опции --bind и --remove)
# 
# Опции:
# -c, --columns "Число"                    количество колонок у игрового поля (по-умолчанию: 10)
# -l, --lines   "Число"                    количество строк у игрового поля (по-умолчанию: 20)
# 
# -a, --align "right|left|top|bottom"      к какой границе окна терминала прижать игровое поле (по умолчанию: -a right -a top)
#     --background-path "Путь к каталогу"  путь к каталогу с фоновыми ascii изображениями (по умолчанию: ./backgrounds/18+)
# -s, --show-hotkeys                       вывести подсказку по клавишам управления (по-умолчанию - не выводить подсказку)
# 
# -b, --bind "Комбинация клавиш"           привязать вызов игры к комбинации клавиш (только при запуске в текущей оболочке, иначе игнорируется); комбинацию клавиш можно получить: [Ctrl+V] + [нужная комбинация]
# -r, --remove                             удалить скрипт из текущей оболочки (только при запуске в текущей оболочке, иначе игнорируется)
# 
# -h, --help                               показывает эту подсказку
# 
# Примеры:
# abstet18+.bash
# abstet18+.bash --align left --align top --show-hotkeys --lines 30 --columns 15
# . abstet18+.bash --background-path ~/abstet18+/sources/backgrounds/18+/ --bind ^[t
# . abstet18+.bash --remove


shopt -s extglob																					# Enables extended globbing patterns, such as, for example, !(this|that) (which would match like * but not any name that is this or that).
shopt -s checkjobs																					# If set, Bash lists the status of any stopped and running jobs before exiting an interactive shell.
shopt -s checkwinsize																				# If set, Bash checks the window size after each external (non-builtin) command and, if necessary, updates the values of LINES and COLUMNS.



# *************************************************************************************************************************************************************
# * Глобальные переменные (в том числе для работы функций общего назначения)
# *************************************************************************************************************************************************************



# *************************************************************************************************************************************************************
# * Функции общего назначения (можно использовать, как библиотечные)
# *************************************************************************************************************************************************************



# *************************************************************************************************************************************************************
# * Функции, характерные только для задач текущего скрипта
# *************************************************************************************************************************************************************

# -----------------------------------------------------------------------------
# Функция abstet
# тетрис в окне терминала
# Аргументы: см. описание скрипта, проверка аргументов на корректность не производится
# Возвращаемое значение:
# 0 - нет ошибок
# 100 - ошибка: терминал не обладает всеми необходимыми возможностями
# -----------------------------------------------------------------------------
function abstet {

	# 1. Проверка возможностей терминала, инициализация переменных
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	# Массив terminal содержит используемые возможности терминала
	local -A -r terminal=(
		# Абсолютное позиционирование курсора
	#	[raw_address]="vpa"														# vertical position #1 absolute (P)
	#	[column_address]="hpa"													# horizontal position #1, absolute (P)
		[cursor_address]="cup"													# move to row #1 columns #2
		# Относительные перемещения курсора
	#	[cursor_down]="cud1"													# down one line
	#	[cursor_left]="cub1"													# move left one space
	#	[cursor_right]="cuf1"													# non-destructive space (move right one space)
	#	[cursor_up]="cuu1"														# up one line
		# Показать/скрыть курсор
		[cursor_hide]="civis"													# make cursor invisible
		[cursor_show]="cnorm"													# ake cursor appear normal (undo civis/cvvis)
		# Звуковой сигнал
	#	[bell]="bel"															# audible signal (bell) (P)
		# Получить информацию о терминале
		[screen_columns]="cols"													# Число столбцов
		[screen_raws]="lines"													# Число строк
		# Очистка
		[screen_clear]="clear"													# clear screen and home cursor (P*)
	#	[raw_clear_eol]="el"													# clear to end of line (P)
	#	[raw_clear_begin]="el1"													# clear to beginning of line
		# Сохранние/восстановление экрана
		[screen_save]="smcup"													# string to start programs using cup
		[screen_restore]="rmcup"												# strings to end programs using cup
	)

	# -----------------------------------------------------------------------------
	# Функция abstet_check_terminal_capabilities
	# проверяет возможности терминала на соответствие нужным функциям, описанных в
	# массиве teminal
	# Аргументы: нет
	# Возвращаемое значение:
	# 0 - терминал обладает нужными функциями
	# 100 - ошибка: терминал не обладает всеми необходимыми возможностями
	# -----------------------------------------------------------------------------
	function abstet_check_terminal_capabilities {
		local tmpstr="${terminal[*]}"
		tmpstr=$(infocmp -1 2>/dev/null | grep -wEc "${tmpstr// /|}")								# Ищем в выводе команды infocmp элементы массива terminal
		[[ $tmpstr -ne ${#terminal[@]} ]] && return 100												# 100 - ошибка: терминал не обладает всеми необходимыми возможностями
		return 0
	} # abstet_check_terminal_capabilities
	# -----------------------------------------------------------------------------

	abstet_check_terminal_capabilities
	[[ $? -eq 100  ]] && return 100																	# 100 - ошибка: терминал не обладает всеми необходимыми возможностями

	# 2. Объявление переменных и внутренних функций
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	# Ассоциативный массив opt содержит параметры игры
	local -A opt=(
		# Окно терминала
		[window_width]=""														# Окно терминала: количество столбцов
		[window_height]=""														# Окно терминала: количество строк
		# Игровое поле
		[board_width]=10														# Игровое поле: количество столбцов
		[board_height]=20														# Игровое поле: количество строк
		[board_align_x]="right"													# Игровое поле: прилипание к границе окна терминала "left" - к левой, "right" - к правой
		[board_align_y]="top"													# Игровое поле: прилипание к границе окна терминала "top" - к верхней, "bottom" - к нижней
		[board_x]=0																# Игровое поле: начальный столбец; если [board_align_x] определено, то определяется автоматически
		[board_y]=0																# Игровое поле: начальная строка; если [board_align_y] определено, то определяется автоматически
		[board_empty_raw]=""													# Пустая строка игрового поля
		[board_empty_ceil]=""													# Пустая ячейка игрового поля (2 символа)
		[board_filler]="········································································································································································································"
		# Параметры фонового процесса
		[pid_ticker]=0															# PID фонового процесса, который генерирует игровую команду cmd[drop_soft]
		[tick]="16650"															# Минимальная временная задержка в микросекундах при генерации игровой команды cmd[drop_soft]
		# Параметры текущей фигуры
		[tetromino]=""															# Имя массива tetromino_? текущей фигуры
		[tetromino_x1]=""														# Имя вспомогательного массива tetromino_?_x1 текущей фигуры
		[tetromino_x2]=""						 								# Имя вспомогательного массива tetromino_?_x2 текущей фигуры
		[tetromino_y1]=""														# Имя вспомогательного массива tetromino_?_y1 текущей фигуры
		[tetromino_y2]=""														# Имя вспомогательного массива tetromino_?_y2 текущей фигуры
		[x]=""																	# Игровая координата фигуры по оси X
		[y]=""																	# Игровая координата фигуры по оси Y
		[shift]=""																# Смещение в массиве tetromino_? текущей фигуры - "угол поворота" ( у tetromino_o всега 0, у прочих - 0, 4, 8, 12 )
		[up]=""																	# Верхняя граница проекции фигуры на ось Y относительно коордитнаты y
		[down]=""																# Нижняя граница проекции фигуры на ось Y относительно коордитнаты y
		[left]=""																# Левая граница проекции фигуры на ось X относительно коордитнаты х
		[right]=""																# Правая граница проекции фигуры на ось X относительно коордитнаты х
		[y_shadow]=""															# Тень фигуры: координата по оси Y
		[shadow]="++"															# Тень фигуры: визуальный элемент
		# Флаги состояний
		[state_video_buffer]=""													# Флаг текущего состояния видеобуфера: "partial" - требуется частичная перерисовка, "full" - требуется полная перерисовка, "SIGWINCH" - запрос полной перерисовки от обработчика сигнала SIGWINCH
		[state_pause]=""														# Флаг паузы: если не определён или пуст - игра, иначе - пауза
		[state_game_over]=""													# Флаг окончания игры: если не определён или пуст - игра, иначе - конец игры
		[state_show_help]=""													# Флаг окна с помощью по клавишам: если не определён или пуст - не показывать, иначе - показывать
		# Уровень, следующая фигура, подсчёт очков и т.п.
		[next]=""																# Символ следующей фигуры (o,i,l,j,s,z,t) для вывода в рамку
		[level]=""																# Текущий уровень (индекс в массиве levels)
		[scores]=""																# Набранное в текущей игре количество очков
		[lines]=""																# Счётчик количества удалённых линий в текущей игре
		[combo]=""																# Счётчик успешных (с удалением линий) непрерывных последовательностей сброса
		[BtB]=""																# Флаг Back-to-Back (BtB): установлен, если предыдущий сброс удалил 4 линии
		# Фон
		[background_path]=""													# Путь к каталогу с ascii изображениями: путь к текущему скрипту + ./backgrounds
		[background_mask]="*"													# Маска для выборки ascii изображениями
		[background]=-1															# Индекс текущей картинки в массиве backgrounds или -1, если картинки нет
	)

	# Массивы игрового поля
	local -a board																# Массив board содержит столбцы игрового поля без текущей фигуры
	# shellcheck disable=SC2034													# Don't warn about next commands
	local -a video_buffer_1														# Массив video_buffer_1 - содержит столбцы игрового поля с наложенной фигурой
	# shellcheck disable=SC2034													# Don't warn about next commands
	local -a video_buffer_2														# Массив video_buffer_2 - содержит столбцы игрового поля с наложенной фигурой
	local -g -n abstet_video_buffer_active="video_buffer_1"						# Глобальная (!) ссылка на активный (текущий) массив video_buffer_?
	local -g -n abstet_video_buffer_prev="video_buffer_2"						# Глобальная (!) ссылка на массив video_buffer_?, вывод из которого был ранее

	# Массив frame содержит элементы рамки игрового поля
	local -a -r frame=( "┌" "┐" "└" "┘" "│" "──" "░" "░░" "vv" "█" "▄▄" "├" )

	# Массив levels содержит стандартное число "NTSC Frames per Cell" для каждого уровня игры, определяющее скорость падения фигуры
	# Время (в секундах) падения фигуры на дно для каждого уровня в оригинальном Тетрисе для NES в версии NTSC:
	#  0: 15.974	 1: 14.310	 2: 12.646	 3: 10.982	 4: 9.318	 5: 7.654	 6: 5.990	 7: 4.326	 8: 2.662	 9: 1.997
	# 10: 1.664		11:  1.664	12:  1.664	13:  1.331	14:  1.331	15: 1.331	16: 0.998	17: 0.998	18: 0.998	19: 0.666
	# 20: 0.666		21:  0.666	 22: 0.666	23:  0.666	24:  0.666	25: 0.666	26: 0.666	27: 0.666	28: 0.666	29: 0.333
	local -a -r levels=( 48 43 38 33 28 23 18 13 8 6 5 5 5 4 4 4 3 3 3 2 2 2 2 2 2 2 2 2 2 1 )

	# Массив tetrominos содержит имена массивов фигур
	local -a -r tetrominoes=( tetromino_{o,i,l,j,s,z,t} )

	# Фигура O
	local -a tetromino_o_x{1..2}
	local -a tetromino_o_y{1..2}
	# shellcheck disable=SC2034																		# Don't warn about next commands
	local -a tetromino_o=(
		''
		'  [][]'
		'  [][]'
		''
	)

	# Фигура I
	local -a tetromino_i_x{1..2}
	local -a tetromino_i_y{1..2}
	# shellcheck disable=SC2034																		# Don't warn about next commands
	local -a tetromino_i=(
		''
		'[][][][]'
		''
		''

		'  []'
		'  []'
		'  []'
		'  []'

		''
		'[][][][]'
		''
		''

		'  []'
		'  []'
		'  []'
		'  []'
	)

	# Фигура L
	local -a tetromino_l_x{1..2}
	local -a tetromino_l_y{1..2}
	# shellcheck disable=SC2034																		# Don't warn about next commands
	local -a tetromino_l=(
		'    []'
		'[][][]'
		''
		''

		'  []'
		'  []'
		'  [][]'
		''

		''
		'[][][]'
		'[]'
		''

		'[][]'
		'  []'
		'  []'
		''
	)

	# Фигура J
	local -a tetromino_j_x{1..2}
	local -a tetromino_j_y{1..2}
	# shellcheck disable=SC2034																		# Don't warn about next commands
	local -a tetromino_j=(
		'[]'
		'[][][]'
		''
		''

		'  [][]'
		'  []'
		'  []'
		''

		''
		'[][][]'
		'    []'
		''

		'  []'
		'  []'
		'[][]'
		''
	)

	# Фигура S
	local -a tetromino_s_x{1..2}
	local -a tetromino_s_y{1..2}
	# shellcheck disable=SC2034																		# Don't warn about next commands
	local -a tetromino_s=(
		'  [][]'
		'[][]'
		''
		''

		'[]'
		'[][]'
		'  []'
		''

		'  [][]'
		'[][]'
		''
		''

		'[]'
		'[][]'
		'  []'
		''
	)

	# Фигура Z
	local -a tetromino_z_x{1..2}
	local -a tetromino_z_y{1..2}
	# shellcheck disable=SC2034																		# Don't warn about next commands
	local -a tetromino_z=(
		'[][]'
		'  [][]'
		''
		''

		'  []'
		'[][]'
		'[]'
		''

		'[][]'
		'  [][]'
		''
		''

		'  []'
		'[][]'
		'[]'
		''
	)

	# Фигура T
	local -a tetromino_t_x{1..2}
	local -a tetromino_t_y{1..2}
	# shellcheck disable=SC2034																		# Don't warn about next commands
	local -a tetromino_t=(
		'  []'
		'[][][]'
		''
		''

		'  []'
		'  [][]'
		'  []'
		''

		''
		'[][][]'
		'  []'
		''

		'  []'
		'[][]'
		'  []'
		''
	)

	# Ассоциативный массив cmd содержит игровые команды, которыми обмениваются субпроцессы скрипта
	local -A -r cmd=(
		[right]=0		[left]=1		[rotate]=2		[rotate_ccw]=3 	[drop_soft]=4		[drop_hard]=5		[level_up]=6	[level_down]=7
		[game_new]=8	[game_pause]=9	[game_quit]=A	[game_redraw]=B [game_help]=C
		[board_left]=D	[board_right]=E	[board_up]=F	[board_down]=G	[board_to_left]=H	[board_to_right]=I	[board_to_up]=J	[board_to_down]=K
	)

	# Массив help содержит строки для вывода подсказки по клавишам
	# shellcheck disable=SC2034																		# Don't warn about next commands
	local -a -r help=(
		"┌ Hotkeys ───────────┐"
		"│(n)ew (q)uit (p)ause│░"
		"│(r)edraw     (h)elp │░"
		"│move: ← → level: + -│░"
		"│rotate: ↑   Ctrl + ↑│░"
		"│drop:   ↓   Space   │░"
		"│board:   Alt + ←↑↓→ │░"
		"│Home End PgUp PgDown│░"
		"└────────────────────┘░"
		"  ░░░░░░░░░░░░░░░░░░░░░"
	)

	# Массив с именами файлов ascii изображений
	local -a backgrounds

	# -----------------------------------------------------------------------------
	# Функция abstet_background_init
	# инициализирует массив с именами файлов фоновых ascii изображений
	# Аргументы: нет
	# Возвращаемое значение:
	# 0 - нет ошибок
	# 100 - ошибка: каталог с ascii изображениями не обнаружен
	# -----------------------------------------------------------------------------
	function abstet_background_init {

		[[ ! -d ${opt[background_path]} ]] && return 100											# 100 - ошибка: каталог с ascii изображениями не обнаружен
		# shellcheck disable=SC2086																	# Don't warn about next commands
		mapfile -t backgrounds < <(	find "${opt[background_path]}/"${opt[background_mask]} -type f | sort --random-sort)	# Получить построчный список файлов из каталога и отсортировать его случайным образом
		(( ${#backgrounds[@]} > 0 )) && opt[background]=0

		return 0
	} # abstet_background_init

	# -----------------------------------------------------------------------------
	# Функция abstet_background_next
	# устанавливает следующее фоновое ascii изображение
	# Аргументы: нет
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_background_next {

		(( opt[background] >= 0 )) && (( opt[background]++ ))										# Если opt[background]=-1, то массив backgrounds не инициализирован
		(( opt[background] >= ${#backgrounds[@]} )) && (( opt[background] = 0 ))					# Если индекс вышел за пределы массив backgrounds, то нпереходим к первому элементу
		opt[state_video_buffer]="full"																# Запрашиваем полную перерисовку игрового поля

		return 0
	} # abstet_background_next

	# -----------------------------------------------------------------------------
	# Функция abstet_background_previous
	# устанавливает предыдущее фоновое ascii изображение
	# Аргументы: нет
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_background_previous {

		(( opt[background] < 0 )) && return 0														# Если opt[background]=-1, то массив backgrounds не инициализирован
		(( opt[background]-- ))
		(( opt[background] < 0 )) && (( opt[background] = ${#backgrounds[@]} - 1 ))					# Если индекс вышел за пределы массив backgrounds, то переходим к последнему элементу
		opt[state_video_buffer]="full"																# Запрашиваем полную перерисовку игрового поля

		return 0
	} # abstet_background_previous

	# -----------------------------------------------------------------------------
	# Функция abstet_background_put
	# выводит в окно терминала текущее фоновое ascii изображение
	# Аргументы: нет
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_background_put {

		(( opt[background] >= 0 )) && cut -c "1-${opt[window_width]}" "${backgrounds[opt[background]]}" | head --lines "${opt[window_height]}"

		return 0
	} # abstet_background_put

	# -----------------------------------------------------------------------------
	# Функция abstet_tetrominoes_render
	# инициализирует вспомогательные массивы tetromino_?_x{1..2} и tetromino_?_y{1..2}
	# для уменьшения рассчётов во время игры
	# tetromino_?_x1 - соответсвует массиву каждой фигуры tetromino_? и содержит для
	#				каждой строки число пустых ячеек перед не пустыми
	# tetromino_?_x2 - соответсвует массиву каждой фигуры tetromino_? и содержит для
	#				каждой строки подстроку с не пустыми ячейками строки
	# tetromino_?_y1 - соответствует массиву каждой фигуры tetromino_? и содержит строки,
	#				каждая из которых соответсвует одному из положений ("повороту") фигуры,
	#				и содержит четыре числа, каждое из которых равно числу пустых ячеек
	#				перед не пустыми для каждого столбца фигуры
	# tetromino_?_y2 - соответствует массиву каждой фигуры tetromino_? и содержит строки,
	#				каждая из которых соответсвует одному из положений ("повороту") фигуры,
	#				и содержит четыре числа, каждое из которых равно числу пустых ячеек
	#				после не пустых для каждого столбца фигуры
	# Аргументы: нет
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_tetrominoes_render {

		local i j tmp1 tmp2
		local -i k l m
		local -a arr

		for i in "${tetrominoes[@]}"; do															# Цикл по каждой фигуре
			local -n tetromino="${i}"
			local -n tetromino_x1="${i}_x1"
			local -n tetromino_x2="${i}_x2"
			local -n tetromino_y1="${i}_y1"
			local -n tetromino_y2="${i}_y2"

			# Заполняем массивы tetromino_?_x{1..2}
			for j in "${tetromino[@]}"; do
				if [[ -z "$j" ]]; then
					tetromino_x1[${#tetromino_x1[@]}]=8												# tetromino_x1[?]: число пробелов в начале фигуры
					tetromino_x2[${#tetromino_x2[@]}]=""											# tetromino_x2[?]: строка с символами фигуры без пробелов в начале и на конце
				else
					tmp1="${j##+([[:space:]])}"														# tmp1: j без пробелов в начале
					(( tetromino_x1[${#tetromino_x1[@]}] = ${#j} - ${#tmp1} ))						# tetromino_x1[?]: число пробелов в начале фигуры
					tmp2="${tmp1%%+([[:space:]])}"													# tmp2: j без пробелов в начале и конце
					tetromino_x2[${#tetromino_x2[@]}]="$tmp2"										# tetromino_x2[?]: строка с символами фигуры без пробелов в начале и на конце
				fi
			done

			# Заполняем массив tetromino_?_y1{1..}
			for (( j = 0; j < 16 && j < ${#tetromino[@]}; j += 4 )); do
				 # заполняем tetromino_y1
				arr=( 4 4 4 4 )
				for (( k = 3; k >= 0; k-- )); do
					tmp1="${tetromino[(( j + k ))]}"												# tmp1: строка массива tetromino для анализу каждой ячейки
					for (( l = 0, m = 0; l < ${#tmp1}; l += 2, m++ )); do
						[[ "${tmp1:l:2}" != '  ' ]] && (( arr[m] = k ))								# если ячейка tmp1 не пустая, то корректируем число пустых клеток над не пустыми
					done
				done
				 # заполняем tetromino_y2
				tetromino_y1[${#tetromino_y1[@]}]="${arr[*]}"										# tetromino_y[?] - число пустых ячеек под не пустыми для текущего положения ("поворота") фигуры
				arr=( 4 4 4 4 )
				for (( k = 0; k < 4 ; k++ )); do
					tmp1="${tetromino[(( j + k ))]}"												# tmp1: строка массива tetromino для анализу каждой ячейки
					for (( l = 0, m = 0; l < ${#tmp1}; l += 2, m++ )); do
						[[ "${tmp1:l:2}" != '  ' ]] && (( arr[m] = 3 - k ))							# если ячейка tmp1 не пустая, то корректируем число пустых клеток под не пустыми
					done
				done
				tetromino_y2[${#tetromino_y2[@]}]="${arr[*]}"										# tetromino_y[?] - число пустых ячеек под не пустыми для текущего положения ("поворота") фигуры
			done

			# Освобождаем память, уничтожая ненужные массивы
			unset "$i"
		done

		return 0
	} # abstet_tetrominoes_render

	# -----------------------------------------------------------------------------
	# Функция abstet_ticker_ctl
	# перезапускает или останавливает фоновый процесс, генерирующий игровую команду
	# cmd[drop_soft]
	# Аргументы:
	# $1:	restart - перезапуск (запуск) процесса
	# 		stop - остановка процесса (по умолчанию)
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_ticker_ctl {

		# 1. Останавливаем процесс, генерирующий игровую команду cmd[drop_soft]
		# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		if [[ "${opt[pid_ticker]}" -ne 0 && -n $(ps --no-headers "${opt[pid_ticker]}") ]]; then
			kill "${opt[pid_ticker]}" 2>/dev/null
			wait "${opt[pid_ticker]}" 2>/dev/null
		fi
		opt[pid_ticker]=0

		if [[ "$1" == "restart" ]]; then
			# 2. Перезапускаем процесс, генерирующий игровую команду cmd[drop_soft]
			# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			# {} - дочерний процесс, который бесконечно выполяется в фоновом режиме
			# Управление процессом:
			# 	сигнал SIGUSR1 - уменьшить уровень
			# 	сигнал SIGUSR2 - увеличить уровень
			{
				local -i epochtime_fixed=${EPOCHREALTIME/[^[:digit:]]/}								# Число микросекунд в эпохе linux (убираем разделитель)
				local -i epochtime_current
				local -i counter=0																	# Счётчик минимальных временных задержек opt[tick]
				# shellcheck disable=SC2030															# Don't warn about next commands
				local -i level="${opt[level]}"														# Уровень игры выставляем по opt[level], далее при изменении opt[level] управлять уровнем будем при помощи сигналов SIGUSR1 и SIGUSR2

				trap "(( level >  0 )) && (( level-- ))" SIGUSR1									# Устанавливаем обработчик сигнала SIGUSR1 для текущего процесса
				trap "(( level < 29 )) && (( level++ ))" SIGUSR2									# Устанавливаем обработчик сигнала SIGUSR2 для текущего процесса

				while true; do																		# Бесконечный цикл
					epochtime_current=${EPOCHREALTIME/[^[:digit:]]/}								# Число микросекунд в эпохе linux (убираем разделитель)
					if (( ( epochtime_current - epochtime_fixed ) >= opt[tick] )); then				# Если прошедшее число микросекунд больше минимальной временной задержки
						(( ( (++counter) % levels[level] ) == 0 )) && echo -n "${cmd[drop_soft]}"	# , то увеличиваем счётчик и если для текущего уровня игры наступило событие cmd[drop_soft], то посылаем команду в stdout
						epochtime_fixed=${EPOCHREALTIME/[^[:digit:]]/}								# Фиксируем новое значение времени
					fi
				done
			} &
			opt[pid_ticker]=$!																		# Сохраняем PID запущенного в background только что процесса
		fi

		return 0
	} # abstet_ticker_ctl

	# -----------------------------------------------------------------------------
	# Функция abstet_video_buffer_exchange
	# меняет местами ссылки на массивы abstet_video_buffer_active и abstet_video_buffer_prev
	# Аргументы: нет
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_video_buffer_exchange {

		if [[ "${!abstet_video_buffer_active}" == "video_buffer_1" ]]; then
			unset -n abstet_video_buffer_active
			unset -n abstet_video_buffer_prev
			# shellcheck disable=SC2034																# Don't warn about next commands
			local -g -n abstet_video_buffer_active="video_buffer_2"
			# shellcheck disable=SC2034																# Don't warn about next commands
			local -g -n abstet_video_buffer_prev="video_buffer_1"
		else
			unset -n abstet_video_buffer_active
			unset -n abstet_video_buffer_prev
			# shellcheck disable=SC2034																# Don't warn about next commands
			local -g -n abstet_video_buffer_active="video_buffer_1"
			# shellcheck disable=SC2034																# Don't warn about next commands
			local -g -n abstet_video_buffer_prev="video_buffer_2"
		fi

		return 0
	} # abstet_video_buffer_exchange

	# -----------------------------------------------------------------------------
	# Функция abstet_video_buffer_render
	# накладывает текущую фигуру на игровое поле в активном видеобуффере, поднимая
	# флаг необходимости частичной перерисовки; при необходимости производит фиксацию
	# фигуры в массиве игрового поля board, тогда флаг необходимости перерисовки не
	# поднимается
	# Аргументы:
	# если $1 == "commit" (режим фиксации фигуры в массиве board), то производится
	# фиксация фигуры в массиве board, тень не фигуры прорисовывается, флаг
	# перерисовки не поднимается
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_video_buffer_render {

		local -a draft																				# Черновой массив, в котором будем делать наложение фигуры на игрвоое поле
		local line																					# Текущая накладываемая строка
		# shellcheck disable=SC2178																	# Don't warn about next commands
		local -n tetromino_x1="${opt[tetromino_x1]}"												# tetromino_x1 указывает на массив tetromino_?_x1 фигуры
		# shellcheck disable=SC2178																	# Don't warn about next commands
		local -n tetromino_x2="${opt[tetromino_x2]}"												# tetromino_x2 указывает на массив tetromino_?_x2 фигуры
		local -i i																					# Индекс текущей обрабатываемой строки из board
		local -i j=$(( ( opt[y] < 0 ) ? opt[shift] - opt[y] : opt[shift] + opt[up] ))				# Индекс фигуры в массивах tetromino_x1 и tetromino_x2 при отрисовке фигуры
		local -i up=$(( opt[y] + opt[up] ))															# Индекс начальной строки board, с которой игровое поле содержит элементы фигуры
		local -i down=$(( opt[y] + opt[down] ))														# Индекс конечной строки board, по которую игровое поле содержит элементы фигуры
		local -i j_shadow=$(( opt[shift] + opt[up] ))												# Индекс фигуры в массивах tetromino_x1 и tetromino_x2 при отрисовке тени
		local -i up_shadow=$(( opt[y_shadow] + opt[up] ))											# Индекс начальной строки board, с которой игровое поле содержит элементы тени
		local -i down_shadow=$(( opt[y_shadow] + opt[down] ))										# Индекс конечной строки board, по которую игровое поле содержит элементы тени
		local -i left																				# Индекс начального символа в строке board, с которой строка содержит элементы фигуры или тени
		local -i right																				# Индекс конечного символа в строке board, по который строка содержит элементы фигуры или тени
		local tmpstr

		# 1. Формируем черновой видеобуфер
		# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		# Вывод строк board с наложенной текущей фигурой и обрамлением по краям
		# frame=([0]="┌" [1]="┐" [2]="└" [3]="┘" [4]="│" [5]="──" [6]="░" [7]="░░" [8]="vv" [9]="█" [10]="▄▄" [11]="├")
		for i in "${!board[@]}"; do
			if (( i < up || i > down )); then
				# Выводимая линия не содержит элементов фигуры
				if [[ -z "$1" ]] && (( opt[y_shadow] > 0 && opt[y_shadow] < ${#board[@]} )) && (( i >= up_shadow && i <= down_shadow )); then
					# Требуется вывести тень
					(( left = opt[x] + tetromino_x1[j_shadow] ))
					(( right = left + ${#tetromino_x2[j_shadow]} - 1 ))
					# Все элементы тени всегда по определению лежат на игровом поле (иначе opt[y_shadow == -1])
					tmpstr="${opt[board_empty_raw]:0:${#tetromino_x2[${j_shadow}]}}"
					line="${board[${i}]:0:${left}}${tmpstr//${opt[board_empty_ceil]}/${opt[shadow]}}${board[${i}]:(( right + 1 )):(( ${#board[i]} - right - 1 ))}"
					# Обрамляем строку рамкой
					line="${frame[4]}${line}${frame[4]}${frame[6]}"
					(( j_shadow++ ))
				else
					# Режим фиксации фигуры или тень выводить не надо
					line="${frame[4]}${board[${i}]}${frame[4]}${frame[6]}"
				fi
			else
				# Если строка фигуры заслоняет тень, то увеличиваем номер строки, с которой тень будет выводиться
				[[ -z "$1" ]] && (( opt[y_shadow] > 0 && opt[y_shadow] < ${#board[@]} )) && (( i >= up_shadow && i <= down_shadow )) && (( j_shadow++ ))

				# Выводимая линия содержит элементы фигуры
				(( left = opt[x] + tetromino_x1[j] ))
				(( right = left + ${#tetromino_x2[j]} - 1 ))
				if (( right < 0 || left >= ${#board[i]} )); then
					# Выводимая линия не содержит элементов фигуры
					line="${board[${i}]}"
				elif (( left < 0 )); then
					# Левая граница выводимой линии за пределами игрового поля, правая - в его пределах
					line="${tetromino_x2[${j}]:(( ${#tetromino_x2[j]} - right - 1 )):(( right + 1 ))}${board[${i}]:(( right + 1 )):(( ${#board[i]} - right - 1 ))}"
				elif (( right >= ${#board[i]} )); then
					# Левая граница выводимой линии на игровом поле, правая - за пределами
					line="${board[${i}]:0:${left}}${tetromino_x2[${j}]:0:(( ${#board[i]} - left ))}"
				else
					# Все элементы фигуры лежат на игровом поле
					line="${board[${i}]:0:${left}}${tetromino_x2[${j}]}${board[${i}]:(( right + 1 )):(( ${#board[i]} - right - 1 ))}"
				fi
				# Обрамляем строку рамкой
				line="${frame[9]}${line}${frame[9]}${frame[6]}"
				(( j++ ))
			fi
			draft[${#draft[@]}]="$line"
		done

		# Вывод нижней строки игрового поля с проекцией фигуры
		(( left = opt[x] + opt[left] ))
		(( right = opt[x] + opt[right] ))
		line="${opt[board_empty_raw]//${opt[board_empty_ceil]}/${frame[5]}}"						# line содержит нижнюю рамку
		if (( left < 0 && right >= 0 )); then
			# Левая граница выводимой линии за пределами игрового поля, правая - в его пределах
			tmpstr="${opt[board_empty_raw]:0:(( right + 1 ))}"
			line="${tmpstr//${opt[board_empty_ceil]}/${frame[10]}}${line:(( right + 1 )):(( ${#line} - right - 1 ))}"
		elif (( left < ${#line} && right >= ${#line} )); then
			# Левая граница выводимой линии на игровом поле, правая - за пределами
			tmpstr="${opt[board_empty_raw]:${left}:(( ${#line} - left ))}"
			line="${line:0:${left}}${tmpstr//${opt[board_empty_ceil]}/${frame[10]}}"
		elif (( left >=0 && right < ${#line} )); then
			# Все элементы фигуры лежат на игровом поле
			tmpstr="${opt[board_empty_raw]:${left}:(( ${right} - ${left} + 1 ))}"
			line="${line:0:${left}}${tmpstr//${opt[board_empty_ceil]}/${frame[10]}}${line:(( right + 1 )):(( ${#line} - right - 1 ))}"
		fi
		# Обрамляем строку рамкой
		line="${frame[2]}${line}${frame[3]}${frame[6]}"
		draft[${#draft[@]}]="$line"

		# 2. Копируем активный видеобуфер в предыдущий, а черновой видеобуфер в активный
		# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		abstet_video_buffer_exchange																# Активный видеобуфер делаем предыдущим
		abstet_video_buffer_active=( )
		for i in "${!draft[@]}"; do
			abstet_video_buffer_active["$i"]="${draft[${i}]}"
		done

		# 3. Завершающие шаги
		# ~~~~~~~~~~~~~~~~~~~
		if [[ -n "$1" ]]; then
			# Фиксируем фигуру в массиве board, флаг перерисовки видеобуфера не поднимаем
			for i in "${!board[@]}"; do
				board["$i"]="${draft[${i}]:1:${#board[${i}]}}"
			done
		else
			# Для обычного режима поднимаем флаг частичной перерисовки видеобуфера, при этом не понижая степень перерисовки
			[[ -z "${opt[state_video_buffer]}" ]] && opt[state_video_buffer]="partial"
		fi

		return 0
	} # abstet_video_buffer_render

	# -----------------------------------------------------------------------------
	# Функция abstet_tetromino_calculate_projections
	# рассчитывает относительные координаты проекций фигуры (относительно ($1, $2)):
	# opt[left], opt[right] - левая и правая границы проекции фигуры на ось X;
	# opt[up], opt[down] - верхняя и нижнюю границы проекции фигуры на ось Y;
	# opt[y_shadow] - максимально возможная координата на игровом поле по оси Y, в
	# которую можно поместить текущую фигуру
	# Аргументы:
	# $1 - коордианта x текущей фигуры
	# $2 - координата y текущей фигуры
	# Возвращаемое значение:
	# opt[y_shadow]:	-1 если фигуру нельзя поместить по переданным координатам,
	#					иначе - координата проекции фигуры по оси y
	# -----------------------------------------------------------------------------
	function abstet_tetromino_calculate_projections {

		# shellcheck disable=SC2178																	# Don't warn about next commands
		local -n tetromino_x1="${opt[tetromino_x1]}"												# tetromino_x1 указывает на массив tetromino_?_y1 фигуры
		# shellcheck disable=SC2178																	# Don't warn about next commands
		local -n tetromino_x2="${opt[tetromino_x2]}"												# tetromino_x2 указывает на массив tetromino_?_y1 фигуры
		# shellcheck disable=SC2178																	# Don't warn about next commands
		local -n tetromino_y1="${opt[tetromino_y1]}"												# tetromino_y1 указывает на массив tetromino_?_y1 фигуры
		# shellcheck disable=SC2178																	# Don't warn about next commands
		local -n tetromino_y2="${opt[tetromino_y2]}"												# tetromino_y2 указывает на массив tetromino_?_y2 фигуры
		local -i i i_min j

		# Вычисляем левую opt[left] и правую opt[right] границы проекции фигуры на ось X (относительно ($1, $2))
		for (( opt[left] = 4, opt[right] = 0, i = (opt[shift] + 3); i >= opt[shift]; i-- )); do
			(( tetromino_x1[i] < opt[left] )) && (( opt[left]  = tetromino_x1[i] ))
			(( tetromino_x1[i] == 8 )) && continue
			(( j = tetromino_x1[i] + ${#tetromino_x2[i]} ))
			(( j > opt[right] )) && (( opt[right] = j ))
		done
		(( opt[right] -= 1 ))

		# Вычисляем верхнюю границу opt[up] проекции фигуры на ось Y (относительно ($1, $2))
		(( opt[up] = 4 ))
		IFS=' '
		for i in ${tetromino_y1[(( opt[shift] >> 2 ))]}; do
			(( i < opt[up] )) && (( opt[up] = i ))
		done

		# Вычисляем нижнюю границу opt[down] проекции фигуры на ось Y (относительно ($1, $2))
		(( opt[down] = 4 ))
		for i in ${tetromino_y2[(( opt[shift] >> 2 ))]}; do
			(( i < opt[down] )) && (( opt[down] = i ))
		done
		(( opt[down] = 3 - opt[down] ))

		# Вычисляем opt[y_shadow] - максимально возможную координату на игровом поле по оси Y (относительно начала игрового поля)
		if (( ($1 + opt[left]) < 0 || ($1 + opt[right]) >= (opt[board_width]<<1) )); then
			# Проекция фигуры невозможна, т.к. как минимум часть фигуры за пределом игрового поля
			(( opt[y_shadow] = -1 ))
		else
			# Проекция фигуры в пределах игрового поля
			local -i x="$1"																			# x: индекс символа в строке массива board
			local -i y																				# y: индекс перебираемой строки в board
			(( i_min = ${#board[@]} ))																# i_min: будет координата тени с наименьшим значением из столбцов
			for j in ${tetromino_y2[(( opt[shift] >> 2 ))]}; do										# j: количество пустых ячеек под не пустыми у фигуры в текущем столбце
				if (( j < 4 && x >= 0 && x < ${#opt[board_empty_raw]} )); then 						# Если текущий столбец у фигуры не пустой и он расположен на игровом поле
					(( y = $2 + 4 - j ))															# y: первая ячейка игрового поля под не пустой ячейкой фигуры в текущем столбце
					(( y < 0 )) && (( i = -y, y = 0 )) 												# фигура в области своей инициализации, учитываем это
					for (( ; y < ${#board[@]}; y++ )); do											# y: перебираем строки, пока не будет конец поля или не пустая ячейка
						[[ "${board[${y}]:${x}:2}" != "${opt[board_empty_ceil]}" ]] && break
					done
					(( i = y - 4 + j ))																# i: координата тени для текущего столбца
					(( i < i_min  )) && (( i_min = i ))
				fi
				(( x += 2 ))
			done
			(( opt[y_shadow] = ( i_min >= $2 && i_min >=0 ) ? i_min : -1 ))
			(( (opt[y_shadow] + opt[down]) >= ${#board[@]} )) && (( opt[y_shadow] = -1 ))
		fi

		return 0
	} # abstet_tetromino_calculate_projections

	# -----------------------------------------------------------------------------
	# Функция abstet_tetromino_check_intersection
	# тестирует возможность размещения текущей фигуры по переданным координатам ($1, $2)
	# Аргументы:
	# $1 - коордианта x текущей фигуры
	# $2 - координата y текущей фигуры
	# $3 - cмещение в массиве opt[tetromino]
	# Возвращаемое значение:
	# 0 - нет ошибок, фигура успешно расзмещается на игровом поле
	# 100 - ошибка: размещение фигуры по текущим координатам не возможно
	# -----------------------------------------------------------------------------
	function abstet_tetromino_check_intersection {

		local -n tetromino_x1="${opt[tetromino_x1]}"												# tetromino_x1 указывает на массив tetromino_?_y1 фигуры
		# shellcheck disable=SC2178																	# Don't warn about next commands
		local -n tetromino_x2="${opt[tetromino_x2]}"												# tetromino_x2 указывает на массив tetromino_?_y1 фигуры
		local -i x y i j

		for (( i = $3 + 3, y = $2 + 3; i >= $3; i--, y-- )); do										# tetromino[i]: строка текущей фигуры к проверке
			(( ${#tetromino_x2[i]} == 0 )) && continue												# у фигуры текущая строка пустая, переход к следующей строке
			(( y < 0 )) && continue																	# фигура в области своей инициализации - не ошибка, переход к следующей строке
			(( y >= ${#board[@]} && ${#tetromino_x2[i]} > 0 )) && return 100						# фигура вышла не пустой ячейкой за область игрового поля по вертикали
			for (( j = tetromino_x1[i] + ${#tetromino_x2[i]} - 2, x = $1 + j; j >= tetromino_x1[i]; j -= 2, x -= 2 )); do	# ${tetromino[i]:j:2}: содержит не пустую ячейку фигуры
				(( x < 0 || x > (${#board[y]} - 1) )) && return 100 								# фигура вышла не пустой ячейкой за область игрового поля по горизонтали
				[[ "${board[${y}]:${x}:2}" != "${opt[board_empty_ceil]}" ]] && return 100			# не пустая ячейка фигуры накладывается на непустую ячейку игрового поля
			done
		done

		return 0
	} # abstet_tetromino_check_intersection

	# -----------------------------------------------------------------------------
	# Функция abstet_tetromino_move
	# перемещает фигуру по горизонтальной оси
	# Аргументы:
	# $1 - если определён, то переместить на одну позицию влево, иначе - вправо
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_tetromino_move {

		(( ( opt[y] + opt[down] ) < 0 )) && return 0												# Не даём перемещать фигуру, если она ещё не показалась
		local -i x_new step
		# shellcheck disable=SC2015																	# Don't warn about next commands
		[[ -z "$1" ]] && (( step = 2 )) || (( step = -2 ))
		(( x_new = opt[x] + step ))
		(( ( x_new + opt[left] ) < 0 || ( x_new + opt[right] ) > ( opt[board_width] << 1 ) )) && return 0	# С новыми координатами фигура выходит за рамки игрового поля
		if ! abstet_tetromino_check_intersection "$x_new" "${opt[y]}" "${opt[shift]}"; then return 0; fi	# Проверяем возможность поместить фигуру по новым координатам
		(( opt[x] = x_new ))																		# Помещаем фигуру в новые координаты
		abstet_tetromino_calculate_projections "${opt[x]}" "${opt[y]}"								# Перерасчёт проекций фигуры
		abstet_video_buffer_render																	# Обновляем видеобуфер

		return 0
	} # abstet_tetromino_move

	# -----------------------------------------------------------------------------
	# Функция abstet_tetromino_rotate
	# вращает фигуру по часовой стрелке на одно положение
	# Аргументы: нет
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_tetromino_rotate {

		[[ "${opt[tetromino]}" == "tetromino_o" ]] && return 0										# Если текущая фигура tetromino_o, то не вращать

		local -i step=4
		local -i shift_new="${opt[shift]}"

		[[ "$1" == "-" ]] && (( step = -4 ))
		(( shift_new += step ))
		if (( shift_new > 12 )); then
			(( shift_new =  0	))
		elif (( shift_new < 0  )); then
			(( shift_new = 12	))
		fi

		if ! abstet_tetromino_check_intersection "${opt[x]}" "${opt[y]}" "$shift_new"; then			# Проверяем возможность повернуть фигуру
			if (( opt[x] == -2 )); then
				# Если поворот рядом с левой границей игрового поля и фигура выходит за пределы игрового поля, то пробуем оттолкнуться на ячейку от границы
				if ! abstet_tetromino_check_intersection "0" "${opt[y]}" "$shift_new"; then return 0; fi
				(( opt[x] = 0 ))
			elif [[ "${opt[tetromino]}" == "tetromino_i" ]] && (( opt[x] >= (${#opt[board_empty_raw]} - 6) )); then
				# Если поворот рядом с правой границей игрового поля и фигура выходит за пределы игрового поля, то пробуем оттолкнуться на ячейку от границы
				(( step = ${#opt[board_empty_raw]} - 8 ))
				if ! abstet_tetromino_check_intersection "$step" "${opt[y]}" "$shift_new"; then return 0; fi
				(( opt[x] = step ))
			elif (( opt[x] == (${#opt[board_empty_raw]} - 4) )); then
				# Если поворот рядом с правой границей игрового поля и фигура выходит за пределы игрового поля, то пробуем оттолкнуться на ячейку от границы
				(( step = ${#opt[board_empty_raw]} - 6 ))
				if ! abstet_tetromino_check_intersection "$step" "${opt[y]}" "$shift_new"; then return 0; fi
				(( opt[x] = step ))
			else
				return 0
			fi
		fi
		(( opt[shift] = shift_new ))

		abstet_tetromino_calculate_projections "${opt[x]}" "${opt[y]}"								# Перерасчёт проекций фигуры
		abstet_video_buffer_render																	# Обновляем видеобуфер

		return 0
	} # abstet_tetromino_rotate

	# -----------------------------------------------------------------------------
	# Функция abstet_tetromino_drop
	# перемещает фигуру по вертикальной оси
	# Аргументы:
	# $1 - если определён, то hard drop, иначе - soft drop
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_tetromino_drop {

		local -i y_new

		if [[ -n "$1" ]]; then
			# hard drop
			if (( opt[y_shadow] != -1 )); then														# Если у фигуры есть тень, то
				if abstet_tetromino_check_intersection "${opt[x]}" "${opt[y_shadow]}" "${opt[shift]}"; then	# Проверяем возможность поместить фигуру в тень.
					(( opt[y] = opt[y_shadow] ))													# Если можно, то помещаем фигуру в тень
				fi 
			fi
			abstet_video_buffer_render "commit"														# Фиксируем фигуру в массиве board
			abstet_tetromino_delete_raws															# Удаление заполненных строк
			abstet_tetromino_get_next																# Инициализация следующей фигуры
			opt[state_video_buffer]="full"															# Запрашиваем полную перерисовку игрового поля
		else
			# soft drop
			(( y_new = opt[y] + 1 ))
			if abstet_tetromino_check_intersection "${opt[x]}" "$y_new" "${opt[shift]}"; then		# Проверяем возможность поместить фигуру по новым координатам
				# Размещение фигуры по новым координатам
				(( opt[y] = y_new ))																# Если можно, то помещаем фигуру по новым координатам
				abstet_tetromino_calculate_projections "${opt[x]}" "${opt[y]}"						# Перерасчёт проекций фигуры
			else
				if (( opt[y_shadow] == -1 )); then
					opt[state_game_over]=true														# По новым координатам разместить фигуру не удалось и тени нет
				else
					# Фиксация фигуры
					abstet_video_buffer_render "commit"												# Фиксируем фигуру в массиве board
					abstet_tetromino_delete_raws													# Удаление заполненных строк
					abstet_tetromino_get_next														# Инициализация следующей фигуры
				fi
			fi
		fi
		abstet_video_buffer_render																	# Обновляем видеобуфер

		return 0
	} # abstet_tetromino_drop

	# -----------------------------------------------------------------------------
	# Функция abstet_tetromino_delete_raws
	# удаление заполненных строк с игрового поля
	# Аргументы: нет
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_tetromino_delete_raws {

		local -i i j k
		local tmp

		# Удаялем заполненные строки с игрового поля
		for (( k = 0, i = ${#board[@]} - 1; i >= 0; )); do
			tmp="${board[${i}]##*${opt[board_empty_ceil]}*}"										# tmp будет пустой, если строка содержит opt[board_empty_ceil]
			if [[ -z "$tmp" ]]; then																# Если строка пустая, то пропускаем её
				(( i-- ))
				continue
			fi
			for (( j = i; j > 0; j-- )); do															# Цикл по строкам
				board[j]="${board[(( j - 1 ))]}"													# Сдвиг строк
			done
			board[0]="${opt[board_empty_raw]}"														# В начало игрового поля помещаем пустую строку
			(( k++ ))
		done

		if (( k == 0 )); then																		# Если линии не удалялись, то
			(( opt[combo] = 0 ))																	# Cбрасываем счётчик непрерывных последовательностей сбросов с удалением линий
		 	unset 'opt[BtB]'																		# Сбрасываем флаг Back-to-Back (BtB)
			return 0																				# Выходим без начисления очков
		fi

		# Подсчитываем очки
		(( opt[lines] += k ))																		# Увеличиваем счётчик количества удалённых линий в текущей игре
		if (( opt[lines] >= ( (opt[level] + 1) * 10) )); then
			(( opt[level]++ ))																		# Увеличиваем уровень, если позволяет счётчик количества удалённых линий
			kill -SIGUSR2 "${opt[pid_ticker]}" 2>/dev/null											# Посылаем сигнал фоновому процессу увеличить уровень игры
			abstet_background_next																	# Следующее фоновое изображение
		fi

		(( k == 3)) && (( k = 5 ))
		(( k == 4)) && (( k = 8 ))
		(( k *= 100 ))																				# 1 линия: k == 100, 2 линии: k == 200, 3 линии: k == 500, 4 линии: k == 800
		(( i = k * ( opt[level] + 1 ) ))															# В i получаем бонус за текущее удаление линий ([k] x [номер уровня])
		if (( k == 800 )); then																		# Если был сброс 4 линий
			[[ -n "${opt[BtB]}" ]] && (( i = ( i * 3 ) >> 1 ))										# ... и если флаг Back-to-Back (BtB) установлен, то увеличиваем бонус за удаление линий в 1,5 раза
			opt[BtB]=true																			# Поднимаем флаг Back-to-Back (BtB)
		else
		 	unset 'opt[BtB]'																		# Сбрасываем флаг Back-to-Back (BtB)
		fi

		(( opt[scores] += i ))																		# Увеличиваем число очков на бонус за удаление линий
		(( opt[combo] > 0 )) && (( opt[scores] += 50 * opt[combo] * ( opt[level] + 1 ) ))			# Увеличиваем число очков на бонус за комбо
		(( opt[combo]++ ))																			# Увеличиваем счётчик непрерывных последовательностей сбросов с удалением линий

		return 0
	} # abstet_tetromino_delete_raws

	# -----------------------------------------------------------------------------
	# Функция abstet_tetromino_get_next
	# инициализация следующей фигуры
	# Аргументы: нет
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_tetromino_get_next {

		# Текущую фигуру берём из ранее определённой следующей
		opt[tetromino]="tetromino_${opt[next]}"

		# Определяем фигуру, которая будет следующей после текущей
		opt[next]="${tetrominoes[(( RANDOM % ${#tetrominoes[@]} ))]#tetromino_}"

		# Получаем фигуру случайным образов и определяем имена её массивов
		opt[tetromino_x1]="${opt[tetromino]}_x1"
		opt[tetromino_x2]="${opt[tetromino]}_x2"
		opt[tetromino_y1]="${opt[tetromino]}_y1"
		opt[tetromino_y2]="${opt[tetromino]}_y2"

		# Помещаем фигуру в центр по горизонтали без поворота
		(( opt[x] = opt[board_width] - 4 ))
		(( opt[shift] = 0 ))

		# Помещаем не пустые ячейки фигуры на -1 позицию по вертикали
		# shellcheck disable=SC2178																	# Don't warn about next commands
		local -n tetromino_y2="${opt[tetromino_y2]}"												# tetromino_y2 указывает на массив tetromino_?_y2 фигуры
		local -i i
		local -i i_min=4
		for i in ${tetromino_y2[(( opt[shift] >> 2 ))]}; do
			(( i < i_min )) && (( i_min = i ))
		done
		(( opt[y] = i_min - 4 ))

		abstet_tetromino_calculate_projections "${opt[x]}" "${opt[y]}"								# Перерасчёт проекций фигуры

		return 0
	} # abstet_tetromino_get_next

	# -----------------------------------------------------------------------------
	# Функция abstet_game_draw
	# перерисовывает игровое поле содержимым активного видеобуффера
	# Аргументы: нет
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_game_draw {

		local -i tmp1 tmp2

		if [[ "${opt[state_video_buffer]}" == "SIGWINCH" ]]; then									# Если был запрос от обработчика сигнала "SIGWINCH"

			unset COLUMNS
			unset LINES
			opt[window_width]=$(tput "${terminal[screen_columns]}")									# Уточняем новую ширину окна терминала
			opt[window_height]=$(tput "${terminal[screen_raws]}")									# Уточняем новую высоту окна терминала

			# Определяем новое положение игрового поля
			(( tmp1 = opt[window_width] - (opt[board_width] << 1) - 3 ))							# Максимальная координата игрового поля по оси X
			(( tmp2 = opt[window_height] - opt[board_height] - 5 ))									# Максимальная координата игрового поля по оси Y
			[[ -n "${opt[state_show_help]}" ]] && (( tmp2 -= 10 ))									# Если выводится подсказка по клавишам, то учитываем её высоту

			[[ "${opt[board_align_x]}" == "left"   ]] && (( opt[board_x] = 0 ))
			[[ "${opt[board_align_x]}" == "right"  ]] && (( opt[board_x] = tmp1 ))
			[[ "${opt[board_align_y]}" == "top"    ]] && (( opt[board_y] = 0 ))
			[[ "${opt[board_align_y]}" == "bottom" ]] && (( opt[board_y] = tmp2 ))

			(( opt[board_x] > tmp1 )) && (( opt[board_x] = tmp1 ))
			(( opt[board_y] > tmp2 )) && (( opt[board_y] = tmp2 ))
			(( opt[board_x] < 0    )) && (( opt[board_x] = 0 ))
			(( opt[board_y] < 0    )) && (( opt[board_y] = 0 ))

			opt[state_video_buffer]="full"															# Запрашиваем полную перерисовку игрового поля
		fi

		local full_redraw																			# Флаг типа перерисовки: если определён, то перерисовка полная

		if [[ "${opt[state_video_buffer]}" == "partial" ]]; then									# Если запрошена частичная перерисовка
			:
		elif [[ "${opt[state_video_buffer]}" == "full" ]]; then										# Если запрошена полная перерисовка
			full_redraw=true
			tput "${terminal[screen_clear]}"														# Очистка окна для случая полной перерисовки из видеобуфера
			abstet_background_put																	# Вывод фонового ascii изображения
		else																						# Иначе - ничего перерисовывать не надо, выходим
			return 0
		fi

		# Определяем ширину игрового поля
		local -i width																				# Ширина игрового поля в окне терминала

		(( tmp1 = opt[window_width] - opt[board_x] ))
		(( tmp2 = (opt[board_width] << 1) + 3 ))
		(( width = ( tmp1 < tmp2 ) ? tmp1 : tmp2 ))

		# -----------------------------------------------------------------------------
		# Функция abstet_print_array
		# выводит строки из массива $3 на экран по начальным координатам ($1, $3); если
		# задан эталонный массив $4, то производится дополнительная проверка и строка
		# из массива $3 выводятся только если она отлична от аналогичной строки в массиве $4
		# Аргументы:
		# $1 - начальная координата по оси X
		# $2 - начальная координата по оси Y
		# $3 - имя массива со строками к выводу
		# $4 - имя эталонного масива со строками
		# Возвращаемое значение: нет
		# -----------------------------------------------------------------------------
		function abstet_print_array {
			local i
			local -i j=$2
			local -n ref_to_arr1="$3"
			local -n ref_to_arr2="${4:-null}"
			for i in "${!ref_to_arr1[@]}"; do
				(( j >= opt[window_height] )) && break
				if [[ -n "$full_redraw" || "${!ref_to_arr2}" == "null" || "${ref_to_arr1[${i}]}" != "${ref_to_arr2[${i}]}" ]]; then
					tput "${terminal[cursor_address]}" "$j" "$1"
					printf "%s" "${ref_to_arr1[${i}]:0:${width}}" 2>/dev/null
				fi
				(( j++ ))
			done
			return 0
		} # abstet_print_array
		# -----------------------------------------------------------------------------

		local -a arr																				# Массив строк к выводу на экран
		local tmpstr1 tmpstr2

		# 1. Прорисовка заголовка
		# ~~~~~~~~~~~~~~~~~~~~~~~~~~
		tmpstr1="${opt[board_empty_raw]//${opt[board_empty_ceil]}/${frame[8]}}"
		if [[ -n "${opt[state_game_over]}" ]]; then
			tmpstr2="game over"
		else
			[[ -z "${opt[state_pause]}" ]] && tmpstr2="${opt[next]}" || tmpstr2="pause"
		fi
		arr[${#arr[@]}]="${frame[0]}${tmpstr1:0:(( ${#tmpstr1} - ${#tmpstr2} - 2 ))}${frame[4]}${tmpstr2}${frame[11]}${frame[1]}"	# frame=([0]="┌" [1]="┐" [2]="└" [3]="┘" [4]="│" [5]="──" [6]="░" [7]="░░" [8]="vv" [9]="█" [10]="▄▄" [11]="├")
		abstet_print_array "${opt[board_x]}" "${opt[board_y]}" "arr"

		# 2. Прорисовка игрового поля
		# ~~~~~~~~~~~~~~~~~~~~~~~~~~~
		abstet_print_array "${opt[board_x]}" $(( opt[board_y] + 1 )) "abstet_video_buffer_active" "abstet_video_buffer_prev"

		# 3. Прорисовка нижней части
		# ~~~~~~~~~~~~~~~~~~~~~~~~~~
		arr=( )
		arr[${#arr[@]}]="  ${opt[board_empty_raw]//${opt[board_empty_ceil]}/${frame[7]}}${frame[6]}"								# frame=([0]="┌" [1]="┐" [2]="└" [3]="┘" [4]="│" [5]="──" [6]="░" [7]="░░" [8]="vv" [9]="█" [10]="▄▄" [11]="├")
		# shellcheck disable=SC2031																	# Don't warn about next commands
		tmpstr1="Level ${opt[level]}"
		tmpstr2="Scores ${opt[scores]}"
		(( tmp1 = (opt[board_width] << 1) - ${#tmpstr1} + 3 ))
		printf -v arr[${#arr[@]}] "%s%${tmp1}s" "$tmpstr1" "$tmpstr2"
		tmpstr1="Lines ${opt[lines]}"
		tmpstr2=${opt[BtB]:+BtB}
		(( opt[combo] > 0 )) && tmpstr2+=" x${opt[combo]}"
		(( tmp1 = (opt[board_width] << 1) - ${#tmpstr1} + 3 ))
		printf -v tmpstr1 "%s%${tmp1}s" "$tmpstr1" "$tmpstr2"
		tmpstr2="${opt[board_empty_raw]//${opt[board_empty_ceil]}/  }"
		arr[${#arr[@]}]="${tmpstr1}${tmpstr2:0:(( (opt[board_width] << 1) - ${#tmpstr1} + 3 ))}"
		abstet_print_array "${opt[board_x]}" $(( opt[board_y] + opt[board_height] + 2 )) "arr"

		# 4. Прорисовка окна с подсказкой по клавишам
		# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		if [[ -n "$full_redraw" && -n "${opt[state_show_help]}" ]]; then
			abstet_print_array "${opt[board_x]}" $(( opt[board_y] + opt[board_height] + 5 )) "help"
		fi

# TODO - можно удалять - ДЛЯ ОТЛАДКИ - отладочная информация
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#arr=( )
#local -n tetromino_y1="${opt[tetromino_y1]}"
#local -n tetromino_y2="${opt[tetromino_y2]}"
#arr[${#arr[@]}]=""
#arr[${#arr[@]}]="${opt[tetromino]}"
#printf -v arr[${#arr[@]}] "    x:%3d         y:%3d" "${opt[x]}"     "${opt[y]}"
#printf -v arr[${#arr[@]}] "shift:%3d  y_shadow:%3d" "${opt[shift]}" "${opt[y_shadow]}"
#printf -v arr[${#arr[@]}] "   up:%3d      left:%3d" "${opt[up]}"    "${opt[left]}"
#printf -v arr[${#arr[@]}] " down:%3d     right:%3d" "${opt[down]}"  "${opt[right]}"
#arr[${#arr[@]}]="tetromino_y1"
#arr[${#arr[@]}]="${tetromino_y1[(( opt[shift] >> 2 ))]}"
#arr[${#arr[@]}]="tetromino_y2"
#arr[${#arr[@]}]="${tetromino_y2[(( opt[shift] >> 2 ))]}"
#printf -v arr[${#arr[@]}] "combo:%3d       BtB: %s"  "${opt[combo]}" "${opt[BtB]:-none}"
#abstet_print_array "${opt[board_x]}" $(( opt[board_y] + opt[board_height] + 15 )) "arr"

		# 5. Сбрасываем флаг перерисовки видеобуфера
		# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		# Значение "SIGWINCH" будет только если в процессе выполнения данной функции
		# обработчик сигнала SIGWINCH установил это значение, т.к. в начале функции
		# значение "SIGWINCH" у флага меняется на "full". В этом случае, запрашиваем
		# полную перерисовку при следующем вызове данной функции, иначе - сбрасываем
		# флаг.
		# shellcheck disable=SC2015																	# Don't warn about next commands
		[[ "${opt[state_video_buffer]}" == "SIGWINCH" ]] && opt[state_video_buffer]="full" || unset 'opt[state_video_buffer]'

		return 0
	} # abstet_game_draw

	# -----------------------------------------------------------------------------
	# Функция abstet_game_new
	# начало новой игры
	# Аргументы: нет
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_game_new {

		# Очищаем поле: массив board заполняем пустыми ячейками
		board=( )
		local i
		for (( i = 0; i < opt[board_height]; i++ )); do
			board["$i"]="${opt[board_empty_raw]}"
		done

		# Фоновому процессу, который генерирует игровую команду cmd[drop_soft], нужно сбросить уровень до 0
		for (( i = 0; i < opt[level]; i++ )); do
			kill -SIGUSR1 "${opt[pid_ticker]}" 2>/dev/null											# Посылаем сигнал фоновому процессу уменьшить уровень игры
			sleep .050																				# Задержка, чтобы обработчик сигнала успел отработать
		done

		opt[next]="${tetrominoes[(( RANDOM % ${#tetrominoes[@]} ))]#tetromino_}"					# Определяем фигуру, которая будет первой
		opt[level]=0																				# Устанавливаем начальный уровень
		opt[scores]=0																				# Сбрасываем набранное в текущей игре количество очков
		opt[lines]=0																				# Сбрасываем счётчик количества удалённых линий в текущей игре
		opt[combo]=0																				# Сбрасываем cчётчик успешных (с удалением линий) непрерывных последовательностей сброса
		unset 'opt[state_game_over]'																# Сбрасываем флаг окончания игры
		unset 'opt[state_pause]'																	# Сбрасываем флаг режима паузы
		unset 'opt[BtB]'																			# Сбрасываем флаг Back-to-Back (BtB)
		abstet_tetromino_get_next																	# Инициализация новой фигуры
		abstet_video_buffer_render																	# Инициализация видеобуфера игровым полем board
		opt[state_video_buffer]="full"																# Запрашиваем полную перерисовку игрового поля

		return 0
	} # abstet_game_new

	# -----------------------------------------------------------------------------
	# Функция abstet_game_pause
	# ставит игру на паузу
	# Аргументы: нет
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_game_pause {

		[[ -n "${opt[state_game_over]}" ]] && return 0												# Если игра окончена, то режим паузы не работает
		# shellcheck disable=SC2015																	# Don't warn about next commands
		[[ -z "${opt[state_pause]}" ]] && opt[state_pause]=true || unset 'opt[state_pause]'			# Инвертируем режим паузы
		opt[state_video_buffer]="full"																# Запрашиваем полную перерисовку игрового поля

		return 0
	} # abstet_game_pause

	# -----------------------------------------------------------------------------
	# Функция abstet_game_help
	# включает или выключает вывод подсказки по клавишам
	# Аргументы: нет
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_game_help {

		# shellcheck disable=SC2015																	# Don't warn about next commands
		[[ -z "${opt[state_show_help]}" ]] && opt[state_show_help]=true || unset 'opt[state_show_help]'	# Инвертируем режим вывода подсказки
		if [[ "${opt[board_align_y]}" == "bottom" ]]; then											# Если у игрового поля стоит выравнивание по нижей границе окна терминала, то меняем координату по Y у игрового поля
			local -i tmp2
			(( tmp2 = opt[window_height] - opt[board_height] - 5 ))									# Максимальная координата игрового поля по оси Y
			[[ -n "${opt[state_show_help]}" ]] && (( tmp2 -= 10 ))									# Если выводится подсказка по клавишам, то учитываем её высоту
			(( opt[board_y] = ( tmp2 < 0 ) ? 0 : tmp2 ))
		fi

		opt[state_video_buffer]="full"																# Запрашиваем полную перерисовку игрового поля

		return 0
	} # abstet_game_help

	# -----------------------------------------------------------------------------
	# Функция abstet_game_change_level
	# изменяет уровень текущей игры
	# Аргументы:
	# $1 - если определён, то уменьшить уровень, иначе - увеличить
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_game_change_level {

		[[ -n "${opt[state_game_over]}" ]] && return 0												# Если игра окончена, то смена уровня не работает

		# Меняем уровень
		if [[ -n "$1" ]]; then
			if (( opt[level] > 0 )); then
				(( opt[level]-- ))
				kill -SIGUSR1 "${opt[pid_ticker]}" 2>/dev/null										# Посылаем сигнал фоновому процессу уменьшить уровень игры
				[[ -n "${opt[state_pause]}" ]] && opt[state_video_buffer]="full"					# Если игра на паузе, то нужна полная перерисовка
				abstet_background_previous															# Предыдущее фоновое изображение
			fi
		else
			if (( opt[level] < 29 )); then
				(( opt[level]++ ))
				kill -SIGUSR2 "${opt[pid_ticker]}" 2>/dev/null										# Посылаем сигнал фоновому процессу увеличить уровень игры
				[[ -n "${opt[state_pause]}" ]] && opt[state_video_buffer]="full"					# Если игра на паузе, то нужна полная перерисовка
				abstet_background_next																# Следующее фоновое изображение
			fi
		fi

		return 0
	} # abstet_game_change_level

	# -----------------------------------------------------------------------------
	# Функция abstet_game_move_board
	# перемещает игровое поле в окне терминала
	# Аргументы:
	# $1:	"up"	- поднять на 1 строку вверх
	# 		"down"	- опустить на 1 строку вниз
	#		"left"	- переместить на 1 столбец влево
	#		"right" - переместить на 1 столбец вправо
	#		"up_border"		- прижать к верхней границе окна
	#		"down_border"	- прижать к нимжней границе окна
	#		"left_border"	- прижать к левой границе окна
	#		"right_border"	- прижать к правой границе окна
	# Возвращаемое значение: нет
	# -----------------------------------------------------------------------------
	function abstet_game_move_board {

		local -i tmp1 tmp2

		(( tmp1 = opt[window_width] - (opt[board_width] << 1) - 3 ))								# Максимальная координата игрового поля по оси X
		(( tmp2 = opt[window_height] - opt[board_height] - 5 ))										# Максимальная координата игрового поля по оси Y
		[[ -n "${opt[state_show_help]}" ]] && (( tmp2 -= 10 ))										# Если выводится подсказка по клавишам, то учитываем её высоту

		# Меняем кординаты игрового поля
		case "$1" in
			left)			(( opt[board_x] > 0    )) && (( opt[board_x]-- )); unset 'opt[board_align_x]' ;;
			right)			(( opt[board_x] < tmp1 )) && (( opt[board_x]++ )); unset 'opt[board_align_x]' ;;
			up)				(( opt[board_y] > 0    )) && (( opt[board_y]-- )); unset 'opt[board_align_y]' ;;
			down)			(( opt[board_y] < tmp2 )) && (( opt[board_y]++ )); unset 'opt[board_align_y]' ;;
			left_border)	(( opt[board_x] = 0    )); opt[board_align_x]="left"   ;;
			right_border)	(( opt[board_x] = tmp1 )); opt[board_align_x]="right"  ;;
			up_border)		(( opt[board_y] = 0    )); opt[board_align_y]="top"    ;;
			down_border)	(( opt[board_y] = tmp2 )); opt[board_align_y]="bottom" ;;
		esac

		(( opt[board_x] < 0 )) && (( opt[board_x] = 0 ))
		(( opt[board_y] < 0 )) && (( opt[board_y] = 0 ))

		opt[state_video_buffer]="full"																# Запрашиваем полную перерисовку игрового поля

		return 0
	} # abstet_game_move_board

	# -----------------------------------------------------------------------------

	# 3. Парсинг аргументов функции. Проверка на корректность не производится.
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	[[ "$0" != -bash ]] && opt[background_path]="$(readlink -f "$(dirname "$0")")/backgrounds/18+"	# Если был запуск функции в дочерней оболочке, то пытаемся установить путь по-умолчанию
	while true; do																					# В цикле обрабатываем известные аргументы
		case "$1" in
			'-a'|'--align')			if [[ "$2" =~ ^(left|right)$ ]];  then
										opt[board_align_x]="$2"
									elif [[ "$2" =~ ^(top|bottom)$ ]]; then
										opt[board_align_y]="$2"
									fi; 				 		shift 2;	continue	;;
			'--background-path')	opt[background_path]="$2";	shift 2;	continue	;;
			'-b'|'--bind')										shift 2;	continue	;;
			'-c'|'--columns')		opt[board_width]="$2";		shift 2;	continue	;;
			'-l'|'--lines')			opt[board_height]="$2";		shift 2;	continue	;;
			'-r'|'--remove')									shift;		continue	;;
			'-s'|'--show-hotkeys')	opt[state_show_help]=true;	shift;		continue	;;
			'--')												shift;		break; 		;;			# "--" - конец известных аргументов
			*)																break;		;;			# Вызов функции без аргументов или с ошибочными аргументами (тогда - игнорируем их)
		esac
	done

	# 4. Инициализация переменных
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	opt[board_empty_raw]="${opt[board_filler]:0:(( opt[board_width] * 2))}"
	opt[board_empty_ceil]="${opt[board_empty_raw]:0:2}"
	unset 'opt[board_filler]'

	# 5. Сохраняем первоначальный экран, отключаем курсор
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	tput "${terminal[cursor_hide]}"
	tput "${terminal[screen_save]}"
	# При Ctrl+C восстанавливаем курсор. экран и удаляем глобальные объекты
	trap 'tput "${terminal[screen_restore]}"; tput "${terminal[cursor_show]}"; unset abstet_keyseq; unset -n abstet_video_buffer_active; unset -n abstet_video_buffer_prev; unset -f abstet_check_terminal_capabilities; unset -f abstet_background_init; unset -f abstet_background_next; unset -f abstet_background_previous;	unset -f abstet_background_put; unset -f abstet_tetrominoes_render; unset -f abstet_ticker_ctl; unset -f abstet_video_buffer_exchange; unset -f abstet_video_buffer_render; unset -f abstet_tetromino_calculate_projections; unset -f abstet_tetromino_check_intersection; unset -f abstet_tetromino_move; unset -f abstet_tetromino_rotate; unset -f abstet_tetromino_drop; unset -f abstet_tetromino_delete_raws; unset -f abstet_tetromino_get_next; unset -f abstet_game_draw; unset -f abstet_print_array; unset -f abstet_game_new; unset -f abstet_game_pause; unset -f abstet_game_help; unset -f abstet_game_change_level; unset -f abstet_game_move_board' SIGINT

	(
		# 6.1 Подоболочка, преобразующая нажатые клавиши в игровые команды в stdout
		# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

		local -u key k1 k2 k3 k4 k5 str
		declare -A -r commands1=(
			[#N]="${cmd[game_new]}"			[#P]="${cmd[game_pause]}"		[#Q]="${cmd[game_quit]}"	[#R]="${cmd[game_redraw]}"	[#H]="${cmd[game_help]}"
			 [C]="${cmd[right]}"			 [D]="${cmd[left]}"				 [A]="${cmd[rotate]}"
			 [B]="${cmd[drop_soft]}"		 [#]="${cmd[drop_hard]}"		[#+]="${cmd[level_up]}"		[#-]="${cmd[level_down]}"
			[+C]="${cmd[board_right]}"		[+D]="${cmd[board_left]}"		[+A]="${cmd[board_up]}"		[+B]="${cmd[board_down]}"
		)

		abstet_ticker_ctl restart																			# Запускаем фоновый процесс, генерирующий игровую команду

		while read -r -s -n 1 key; do																# Бесконечный цикл с вводом с клавиатуры (-s без эха, -n 1 прочитать один символ)
			case "${k5}${k4}${k3}${k2}${k1}${key}" in												# Отслеживаем последовательность из 6 символов
				$'\x1b'\[[ABCD])		str="${commands1[${key}]}" ;;								# Нажата какая-то стрелка на клавиатуре
				$'\x1b'"[1;5A")			str="${cmd[rotate_ccw]}" ;;									# Нажат Ctrl + стрелка вверх
				$'\x1b'"[1;3"[ABCD])	str="${commands1[+${key}]}" ;;								# Нажаты Alt + какая-то стрелка на клавиатуре
				$'\x1b'"[1~")			str="${cmd[board_to_left]}" ;;								# Нажат Home
				$'\x1b'"[4~")			str="${cmd[board_to_right]}" ;;								# Нажат End
				$'\x1b'"[5~")			str="${cmd[board_to_up]}" ;;								# Нажат PageUp
				$'\x1b'"[6~")			str="${cmd[board_to_down]}"	;;								# Нажат PageDown
				*$'\x1b'$'\x1b')		str="${cmd[game_quit]}" ;;									# Нажат два раза ESC
				*)						str="${commands1[#${key}]:-}" ;;							# Нажата обычная клавиша
			esac
			k5="$k4"; k4="$k3"; k3="$k2"; k2="$k1"; k1="$key"										# Сдвиг последовательности символов
			if [[ -n "$str" ]]; then																# Если $str содержит команду
				k5=""; k4=""; k3=""; k2=""; k1=""													# Очистка последовательности символов
				echo -n "$str"																		# Вывод команды в stdout
				[[ "$str" == "${cmd[game_quit]}" ]] && break										# Если это был выход из игры, то завершаем процесс
			fi
		done

		abstet_ticker_ctl stop																				# Останавливаем фоновый процесс, генерирующий игровую команду

	)|(

		# 6.2 Подоболочка, считывающая игровые команды из stdin
		# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

			# 6.2.1 Инициализация переменных и вспомогательных массивов
			# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			abstet_background_init
			abstet_tetrominoes_render

			# 6.2.2 Получаем PID фонового процесса, который генерирует игровую команду cmd[drop_soft]
			# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			for key in $(pgrep --parent "$$"); do													# В key - PID подоболочек основного процесса программы
				[[ "$key" != "$BASHPID" ]] && break													# Если номер PID у подоболочки не совпадает с PID текущей оболочки, то значит нашли нужный PID
			done
			opt[pid_ticker]=$(pgrep --parent "$key")												# У найденной подоболочки получаем PID дочернего процесса - это и есть искомый PID

			# 6.2.3 Начало новой игры
			# ~~~~~~~~~~~~~~~~~~~~~~~
			abstet_game_new																			# Инициализируем новую игру
			opt[state_video_buffer]="SIGWINCH"														# Запрашиваем полную перерисовку игрового поля с определением параметров окна терминала
			trap "opt[state_video_buffer]=SIGWINCH" SIGWINCH										# Устанавливаем обработчик события при изменении окна терминала
			abstet_game_draw																		# Прорисовываем

			# 6.2.4 Считываем игровые команды из stdin и выполняем их
			# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			local key
			declare -A -r commands2=(
				["${cmd[game_new]}"]="abstet_game_new"
				["${cmd[game_pause]}"]="abstet_game_pause"
				["${cmd[game_quit]}"]="break"
				["${cmd[game_redraw]}"]="opt[state_video_buffer]=full"
				["${cmd[game_help]}"]="abstet_game_help"
				["${cmd[right]}"]="abstet_tetromino_move"
				["${cmd[left]}"]="abstet_tetromino_move -"
				["${cmd[rotate]}"]="abstet_tetromino_rotate"
				["${cmd[rotate_ccw]}"]="abstet_tetromino_rotate -"
				["${cmd[drop_soft]}"]="abstet_tetromino_drop"
				["${cmd[drop_hard]}"]="abstet_tetromino_drop hard"
				["${cmd[level_up]}"]="abstet_game_change_level"
				["${cmd[level_down]}"]="abstet_game_change_level -"
				["${cmd[board_right]}"]="abstet_game_move_board right"
				["${cmd[board_left]}"]="abstet_game_move_board left"
				["${cmd[board_up]}"]="abstet_game_move_board up"
				["${cmd[board_down]}"]="abstet_game_move_board down"
				["${cmd[board_to_right]}"]="abstet_game_move_board right_border"
				["${cmd[board_to_left]}"]="abstet_game_move_board left_border"
				["${cmd[board_to_up]}"]="abstet_game_move_board up_border"
				["${cmd[board_to_down]}"]="abstet_game_move_board down_border"
			)

			while read -r -s -n 1 key; do
				if [[ -n "$key" ]]; then															# Если key содержит игровую команду
					if [[ "$key" == [012345] ]]; then												# Если команда управления фигурой
						 [[ -n "${opt[state_game_over]}" || -n "${opt[state_pause]}" ]] && continue	# Если игра окончена или игра на паузе, то переход к следующей итерации
					fi
					eval "${commands2[${key}]}"														# Выполняем игровую команду
					abstet_game_draw
				fi
			done

			# 6.2.5 Завершаемся
			# ~~~~~~~~~~~~~~~~~
			trap - SIGWINCH																			# Убираем утанавлиенный ранее обработчик события при изменении окна терминала
			abstet_ticker_ctl stop																	# Останавливаем фоновый процесс, генерирующий игровую команду
	)

	# 7. Восстанавливаем первоначальный экран и курсор, удаляем глобальные переменные и функции
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	tput "${terminal[screen_restore]}"; tput "${terminal[cursor_show]}"; unset abstet_keyseq; unset -n abstet_video_buffer_active; unset -n abstet_video_buffer_prev; unset -f abstet_check_terminal_capabilities; unset -f abstet_background_init; unset -f abstet_background_next; unset -f abstet_background_previous;	unset -f abstet_background_put; unset -f abstet_tetrominoes_render; unset -f abstet_ticker_ctl; unset -f abstet_video_buffer_exchange; unset -f abstet_video_buffer_render; unset -f abstet_tetromino_calculate_projections; unset -f abstet_tetromino_check_intersection; unset -f abstet_tetromino_move; unset -f abstet_tetromino_rotate; unset -f abstet_tetromino_drop; unset -f abstet_tetromino_delete_raws; unset -f abstet_tetromino_get_next; unset -f abstet_game_draw; unset -f abstet_print_array; unset -f abstet_game_new; unset -f abstet_game_pause; unset -f abstet_game_help; unset -f abstet_game_change_level; unset -f abstet_game_move_board

	return 0
} # abstet

# -----------------------------------------------------------------------------
# Функция abstet_main
# главная функция скрипта
#
# Аргументы: см. описание скрипта
# Возвращаемое значение:
# 0 - нет ошибок
# 1 - запуск скрипта в текущей оболочке с опцией --remove
# 102 - ошибка функции getopt при обработке аргументов функции main
# 103 - внутренняя ошибка при парсинге аргументов функции main, возможно требуется отладка
# 104 - ошибка в аргументах командной строки
# -----------------------------------------------------------------------------
function abstet_main {

	# 1. Парсинг командной строки
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~

	local __this_filename																			# Имя файла текущего скрипта
	local options																					# Строка с обработанными опциями, в итоге передаётся в функцию игры
	local fl_bind																					# Флаг запуска с опцией --bind
	local fl_remove																					# Флаг запуска с опцией --remove
	local fl_help																					# Флаг запуска с опцией --help
	local fl_error																					# Флаг ошибки в аргументах
	local -a error_msg																				# Массив сообщений об ошибках в аргументах
	local keyseq																					# Назначенная комбинация клавиш при запуске в текущей оболочке (опция --bind)

	# Получаем имя скрипта в зависимости от того, как был он запущен - в дочерней оболочке или текущей
	[[ "$0" != -bash ]] && __this_filename=$(basename "$0") || __this_filename="abstet18+.bash"

	# В $options помещаем обработанную строку с аргументами при вызове скрипта.
	# Известные аргументы (до аргумента "--" ) будут помещены в начало строки, остальные - после.
	if ! options=$(getopt --unquoted --options 'a:b:c:hl:rs' --longoptions 'align:,background-path:,bind:,columns:,help,lines:,remove,show-hotkeys' --name "$__this_filename" -- "$@"); then
		# 102 - ошибка функции getopt при обработке аргументов функции main
		echo "Ошибка функции getopt при обработке аргументов функции main"
		echo "Скрипт завершён с кодом 102"
		return 102
	fi
	eval set -- "$options"																			# Замещаем аргументы функции main на новые из переменной $options

	while true; do																					# В цикле обрабатываем известные аргументы
		case "$1" in
			'-a'|'--align')
				if [[ ! "$2" =~ ^(left|right|top|bottom)$ ]]; then
					fl_error=true
					error_msg[${#error_msg[@]}]="${1} ${2}: неправильное значение опции (допустимые значения: left, right, top, bottom)"
				fi
				shift 2
				continue
				;;
			'--background-path')
				if [[ ! -d $2 ]]; then
					fl_error=true
					error_msg[${#error_msg[@]}]="${1} ${2}: каталог ${2} недоступен"
				fi
				shift 2
				continue
				;;
			'-b'|'--bind')
				fl_bind=true
				keyseq="$2"
				shift 2
				continue
				;;
			'-c'|'--columns')
				if [[ ! "$2" =~ ^[0-9]+$ ]] || (( $2 < 4 || $2 > 30 )); then
					fl_error=true
					error_msg[${#error_msg[@]}]="${1} ${2}: ожидается число от 4 до 30"
				fi
				shift 2
				continue
				;;
			'-h'|'--help')
				fl_help=true
				shift
				continue
				;;
			'-l'|'--lines')
				if [[ ! "$2" =~ ^[0-9]+$ ]] || (( $2 < 4 || $2 > 100 )); then
					fl_error=true
					error_msg[${#error_msg[@]}]="${1} ${2}: ожидается число от 4 до 50"
				fi
				shift 2
				continue
				;;
			'-s'|'--show-hotkeys')
				shift
				continue
				;;
			'-r'|'--remove')
				fl_remove=true
				shift
				continue
				;;
			'--')
				# "--" - конец известных аргументов
				shift
				break
				;;
			*)
				# 103 - внутренняя ошибка при парсинге аргументов функции main, возможно требуется отладка
				echo "Внутренняя ошибка при парсинге аргументов функции main, возможно требуется отладка"
				echo "Скрипт завершён с кодом 103"
				return 103
			;;
		esac
	done

	# Если была запрошена помощь (или остались нераспознаные аргументы командной строки)
	if [[ -n "$fl_help" || "$#" -ne 0 || -n "$fl_error" ]]; then
		echo "${__this_filename}   version 0.1, © 2024 by Sergey Vasiliev aka abs."
		echo "${__this_filename} - Tetris 18+ in the Linux terminal / Тетрис 18+ в окне терминала."
		echo ""
		echo "${__this_filename} comes with ABSOLUTELY NO WARRANTY. This is free software, and you are welcome to redistribute it under certain conditions. See the GNU General Public Licence for details."
		echo ""
		echo "Использование:"
		echo "  вариант 1:   ${__this_filename} [ОПЦИЯ] ..."
		echo "  вариант 2: . ${__this_filename} [ОПЦИЯ] ...  - запуск в текущей оболочке (см. опции --bind и --remove)"
		echo ""
		echo "Опции:"
		echo "-c, --columns \"Число\"                    количество колонок у игрового поля (по-умолчанию: 10)"
		echo "-l, --lines   \"Число\"                    количество строк у игрового поля (по-умолчанию: 20)"
		echo ""
		echo "-a, --align \"right|left|top|bottom\"      к какой границе окна терминала прижать игровое поле (по умолчанию: -a right -a top)"
		echo "    --background-path \"Путь к каталогу\"  путь к каталогу с фоновыми ascii изображениями (по умолчанию: ./backgrounds/18+)"
		echo "-s, --show-hotkeys                       вывести подсказку по клавишам управления (по-умолчанию - не выводить подсказку)"
		echo ""
		echo "-b, --bind \"Комбинация клавиш\"           привязать вызов игры к комбинации клавиш (только при запуске в текущей оболочке, иначе игнорируется); комбинацию клавиш можно получить: [Ctrl+V] + [нужная комбинация]"
		echo "-r, --remove                             удалить скрипт из текущей оболочки (только при запуске в текущей оболочке, иначе игнорируется)"
		echo ""
		echo "-h, --help                               показывает эту подсказку"
		echo ""
		echo "Примеры:"
		echo "abstet18+.bash"
		echo "abstet18+.bash --align left --align top --show-hotkeys --lines 30 --columns 15"
		echo ". abstet18+.bash --background-path ~/abstet18+/sources/backgrounds/18+/ --bind ^[t"
		echo ". abstet18+.bash --remove"


		# Была ошибка в аргументах командной строки
		if [[ $# -ne 0 || -n "$fl_error" ]]; then
			echo ""
			echo ""
			echo "Ошибка в аргументах командной строки: ${*}"
			printf "%s\n" "${error_msg[@]}"
			echo "Скрипт завершён с кодом 104"
			return 104																				# 104 - ошибка в аргументах командной строки
		fi

		return 0
	fi

	if [[ "$0" != -bash ]]; then
		# 2.1 Запускаем игру
		# ~~~~~~~~~~~~~~~~~~
		eval set -- "$options"																		# Замещаем аргументы функции main на новые из переменной $options
		abstet "$@"
	else
		if [[ -n "$fl_remove" ]]; then
			# 2.2 Удаляем назначенную функции abstet ранее комбинацию клавиш и саму функцию abstet
			# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			bind -r "${abstet_keyseq}"
			unset -f abstet
			return 1																				# 1 - запуск скрипта в текущей оболочке с опцией --remove
		elif [[ -n "$fl_bind" ]]; then
			# 2.3 Запуск в текущей оболочке с привязкой функции к комбинации клавиш
			# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			[[ -n "$abstet_keyseq" ]] && bind -r "${abstet_keyseq}"									# Если переменная в окружении существует, то отменяем комбинацию клавиш
			local -g abstet_keyseq																	# Для скрипта с опцией --bind хранит назначенную пользователем комбинацию клавиш
			abstet_keyseq="$keyseq"
			eval set -- "$options"																	# Замещаем аргументы функции main на новые из переменной $options
			bind -x "\"${abstet_keyseq}\":\"abstet ${*}\""
		fi
	fi

	return 0
} # abstet_main



# *************************************************************************************************************************************************************
# * Сам скрипт 😊
# *************************************************************************************************************************************************************

declare abstet_result																				# Результат вызова функции abstet_main
abstet_main "$@"
abstet_result="$?"
[[ "$0" != -bash ]] && exit "$abstet_result"														# Был запуск скрипта в дочерней оболочке
[[ $abstet_result -eq 1 ]] && unset -f abstet_main													# 1 - запуск скрипта в текущей оболочке с опцией --remove
unset abstet_result

# *************************************************************************************************************************************************************
