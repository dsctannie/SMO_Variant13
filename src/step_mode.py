import random
import heapq

class Bid:
    def __init__(self, bid_id, source_id, arrival_time):
        self.id = bid_id
        self.source_id = source_id
        self.arrival_time = arrival_time

class Source:
    """Источник (Клиент). Закон ИЗ2: Равномерный"""
    def __init__(self, source_id, a, b):
        self.id = source_id
        self.a = a
        self.b = b
        self.total_generated = 0  
        self.total_refused = 0    

    def get_next_time(self, current_time):
        # ИЗ2: Равномерный закон распределения
        return current_time + random.uniform(self.a, self.b)

class Buffer:
    """Буфер. Д1033: На свободное место"""
    def __init__(self, capacity):
        self.capacity = capacity
        self.slots = [None] * capacity

    def has_free_place(self):
        return None in self.slots

    def put_bid(self, bid):
        # Д1033: постановка на свободное место
        for i in range(self.capacity):
            if self.slots[i] is None:
                self.slots[i] = bid
                return True
        return False

    def select_bid(self):
        # Д2Б4: приоритет по номеру источника, при равенстве — последняя поступившая
        best_idx = -1
        best_bid = None
        
        for i in range(self.capacity):
            bid = self.slots[i]
            if bid is not None:
                if best_bid is None:
                    best_bid = bid
                    best_idx = i
                else:
                    if bid.source_id < best_bid.source_id:
                        best_bid = bid
                        best_idx = i
                    elif bid.source_id == best_bid.source_id:
                        if bid.arrival_time > best_bid.arrival_time:
                            best_bid = bid
                            best_idx = i
                            
        if best_idx != -1:
            self.slots[best_idx] = None
            return best_bid
        return None

class Device:
    """Прибор. Закон ПЗ1: Экспоненциальный"""
    def __init__(self, device_id, mean_time):
        self.id = device_id
        self.mean_time = mean_time
        self.busy = False
        self.current_bid = None

    def is_free(self):
        return not self.busy

    def serve(self, bid, current_time):
        self.busy = True
        self.current_bid = bid
        # ПЗ1: экспоненциальное обслуживание
        service_time = random.expovariate(1.0 / self.mean_time)
        return current_time + service_time

    def release(self):
        self.busy = False
        self.current_bid = None

class DispatcherSelect:
    """Диспетчер выбора (Д2П1 + Д2Б4)"""
    def __init__(self, buffer, devices):
        self.buffer = buffer
        self.devices = devices

    def select_device(self):
        # Д2П1: приоритет по номеру прибора
        for dev in self.devices:
            if dev.is_free():
                return dev
        return None

def trigger_service(current_time, buffer, dispatcher, event_queue):
    """Триггер: запуск обслуживания при поступлении/освобождении"""
    free_dev = dispatcher.select_device()
    if free_dev:
        bid_to_serve = buffer.select_bid()
        if bid_to_serve:
            end_time = free_dev.serve(bid_to_serve, current_time)
            heapq.heappush(event_queue, (end_time, "END_SERVICE", free_dev))

def run_step_mode(num_sources=3, buffer_size=4, num_devices=2, total_events=20):
    print("="*85)
    print("КАЛЕНДАРЬ СОБЫТИЙ (ОД1) - Вариант 13")
    print("="*85)
    print(f"{'Событие':<10} | {'Время':<8} | {'Признак':<8} | {'Число заявок':<14} | {'Число отказов'}")
    print("-" * 85)

    # Инициализация параметров
    sources = [Source(i+1, 1.0, 5.0) for i in range(num_sources)] 
    buffer = Buffer(buffer_size)
    devices = [Device(i+1, 4.0) for i in range(num_devices)]     
    dispatcher = DispatcherSelect(buffer, devices)
    
    event_queue = []
    bid_counter = 1
    total_generated = 0
    total_refused = 0

    # Планируем первые заявки от всех источников
    for src in sources:
        heapq.heappush(event_queue, (src.get_next_time(0), "NEW_BID", src))

    processed_events = 0

    while event_queue and processed_events < total_events:
        current_time, event_type, data = heapq.heappop(event_queue)
        
        if event_type == "NEW_BID":
            src = data
            bid = Bid(bid_counter, src.id, current_time)
            bid_counter += 1
            total_generated += 1
            
            if buffer.put_bid(bid):
                # Успешно помещена в буфер
                print(f"И{src.id:<9} | {current_time:<8.2f} | {0:<8} | {total_generated:<14} | {total_refused}")
                trigger_service(current_time, buffer, dispatcher, event_queue)
            else:
                # Д1005: отказ вновь пришедшей заявке
                total_refused += 1
                print(f"И{src.id:<9} | {current_time:<8.2f} | {1:<8} | {total_generated:<14} | {total_refused}")

            heapq.heappush(event_queue, (src.get_next_time(current_time), "NEW_BID", src))

        elif event_type == "END_SERVICE":
            dev = data
            dev.release()
            trigger_service(current_time, buffer, dispatcher, event_queue)

        processed_events += 1

    print("="*85)
    print("Моделирование завершено.")

if __name__ == "__main__":
    run_step_mode(num_sources=3, buffer_size=4, num_devices=2, total_events=15)
