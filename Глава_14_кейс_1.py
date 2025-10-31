import re
import os
import numpy
from datetime import datetime

def parse_log_file(filepath: str) -> list[dict]:
    parsed_logs = []
    log_pattern = re.compile(
        r"^(\w+)\s*\|\s*(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2},\d{3})\s*\|\s*"
        r"file:\s*([\w\d\._-]+\.py)\s*\|\s*line:\s*(\d+)\s*\|\s*"
        r"\[demon\]\s*(.*)$"
    )
    info_pattern = re.compile(r"^Обновляем подписку пользователю id:\s*(\d+)")   
    error_pattern = re.compile(r"^У пользователя с id:\s*(\d+)")
    if not os.path.exists(filepath):
        print(f"Ошибка: Файл '{filepath}' не найден.")
        return []

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            prev_row = {}
            for line_num, line in enumerate(f, 1):
                line = line.strip() 
                if not line:
                    continue 
                match = log_pattern.match(line)
                if match:
                    level, timestamp_str, filename, line_number_str, message = match.groups()
                    message = message.strip()
                    try:                        
                        timestamp = datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S,%f")
                    except ValueError as e:
                        print(f"Предупреждение: Не удалось распарсить метку времени в строке {line_num}: '{timestamp_str}'. Ошибка: {e}. Строка: '{line}'")
                        continue

                    try:
                        line_number = int(line_number_str)
                    except ValueError:
                        print(f"Предупреждение: Некорректный номер строки в строке {line_num}: '{line_number_str}'. Строка: '{line}'")
                        continue
                    
                     
                    if (level == 'ERROR' and 'level' in prev_row and prev_row['level'] == 'INFO' and prev_row['success'] == True):
                        match_info = info_pattern.match(prev_row['message'])
                        match_error = error_pattern.match(message)                                                   
                        if match_info and match_error and match_info.group(1) == match_error.group(1):
                            prev_row['success'] = False                            
                
                    prev_row = {
                        'level': level,
                        'timestamp': timestamp,
                        'file': filename,
                        'line': line_number,
                        'message': message.strip()
                    }
                    if level == 'INFO' and info_pattern.match(message):
                        prev_row['success'] = True
                    parsed_logs.append(prev_row)
                else:
                    print(f"Предупреждение: Строка {line_num} не соответствует ожидаемому формату лога: '{line}'")
    except Exception as e:
        print(f"Произошла ошибка при чтении файла '{filepath}': {e}")

    return parsed_logs


def count_success_and_failure(log_file_path):  
    successful_updates_count = 0
    failure_count = 0
    lines = parse_log_file(log_file_path) 
     
    for line in lines:
        if line['level'] == 'INFO' and 'success' in line:
            if line['success'] == True:
                successful_updates_count += 1
            else:
                failure_count += 1
    return (successful_updates_count, failure_count)

def sub_renewal_by_day(file_path):
    lines = parse_log_file(file_path) 
    renewals_by_weekday = {} 
    for line in lines:
        if line['level'] == 'INFO' and 'success' in line and line['success'] == True:
            day = line['timestamp'].weekday()
            if day in renewals_by_weekday:
                renewals_by_weekday[day] += 1
            else:
                renewals_by_weekday[day] = 1    
    print('Количество обновлений подписки по дням недели:')
    days = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье']
    for i in range(7):
        print("{}: {}".format(days[i], renewals_by_weekday[i]))

def auto_renewal_sub(log_file_path):
    lines = parse_log_file(log_file_path)
    info_pattern = re.compile(r"^Cегодня\s*(\d{4}-\d{2}-\d{2}).*подписки:\s*(\d+)$")
    res = {}    
    for line in lines:
        match_info = info_pattern.match(line['message'])
        if line['level'] == 'INFO' and match_info:
            key = match_info.group(1)
            val = int(match_info.group(2))
            if key in res:
                if res[key] < val:
                    res[key] = val
            else:
                res[key] = val
    smoothed = []
    smooth_med = []
    arr = []
    sum = 0
    i = 1
    for item in res.values():
        sum += item
        smoothed.append(float(round(sum/i, 2)))
        i += 1
        arr.append(item)
        smooth_med.append(round(numpy.median(arr)))
    with open("auto_renewal_sub.txt", "w") as f:        
        print("Среднее:", smoothed, file=f)
        print("Медиана:", smooth_med, file=f)
            

#задача 1
res = count_success_and_failure('auto_purchase.log')
print(res)

#задача 2
auto_renewal_sub('auto_purchase.log')

#задача 3
sub_renewal_by_day('auto_purchase.log')