"""
1. ИСТОЧНИК ЗАЯВОК (Клиенты мобильного приложения):
   - ИБ (Бесконечный источник): каждый клиент может оформлять неограниченное
     число новых заказов независимо от предыдущих.
   - ИЗ2 (Равномерный закон распределения): интервалы времени между приходом
     заказов от клиента распределены равномерно на заданном отрезке [a, b].

2. ПРИБОРЫ ОБСЛУЖИВАНИЯ (Диспетчеры службы доставки):
   - ПЗ1 (Экспоненциальный закон распределения): время обработки одного заказа
     диспетчером (проверка адреса, оплата, назначение курьера) подчиняется
     экспоненциальному распределению с заданным средним значением.
   - Каждый диспетчер обслуживает только один заказ одновременно.

3. БУФЕРНАЯ ПАМЯТЬ И ДИСЦИПЛИНА ПОСТАНОВКИ (Очередь заказов в диспетчерской):
   - Д1033 (Заполнение с начала без сдвига): новый заказ занимает первое
     свободное место от начала буфера (индекс 0, 1, 2...). Когда заказ уходит
     на обслуживание, остальные заказы остаются на своих местах (без сдвига).
     Кольцевых указателей в данном варианте нет.

4. ДИСЦИПЛИНА ОТКАЗА (Потеря заказа при перегрузке):
   - Д10О5 (Отказ вновь пришедшей заявке): если при поступлении нового заказа
     все места в буфере заняты, отклоняется и удаляется из системы именно
     вновь пришедший заказ. Состояние очереди не меняется, уже начатая
     обработка других заказов не прерывается. Отказ засчитывается клиенту,
     создавшему этот заказ.

5. ДИСЦИПЛИНЫ ВЫБОРА НА ОБСЛУЖИВАНИЕ:
   - Д2П1 (Приоритет по номеру прибора): при поиске свободного диспетчера
     перебор всегда ведётся последовательно начиная с самого приоритетного
     (Диспетчер 1 -> Диспетчер 2 -> Диспетчер 3 и т.д.).
   - Д2Б4 (Приоритет по номеру источника, по одной заявке): при освобождении
     диспетчера из очереди выбирается ОДНА заявка от клиента-источника с
     наивысшим приоритетом (меньший номер клиента = выше приоритет: И1 > И2 > И3).
     Если в буфере несколько заказов от одного и того же приоритетного клиента,
     выбирается ПОСЛЕДНИЙ поступивший из них (LIFO внутри приоритета).
     Пакетная обработка не используется.

"""

import random
import heapq


class Bid:
    def __init__(self, bid_id: int, source_id: int, arrival_time: float):
        self.__id = bid_id
        self.__source_id = source_id
        self.__arrival_time = arrival_time

    @property
    def id(self) -> int:
        return self.__id

    @property
    def source_id(self) -> int:
        return self.__source_id

    @property
    def arrival_time(self) -> float:
        return self.__arrival_time

    def __str__(self) -> str:
        return f"Заказ #{self.__id} (Клиент {self.__source_id})"


class Source:
    def __init__(self, source_id: int, a: float, b: float):
        self.__id = source_id
        self.__a = a
        self.__b = b
        self.generated = 0
        self.refused = 0

    @property
    def id(self) -> int:
        return self.__id

    def get_next_time(self, current_time: float) -> float:
        # ИЗ2: равномерный закон распределения интервалов поступления
        return current_time + random.uniform(self.__a, self.__b)


class Buffer:
    def __init__(self, capacity: int):
        self.__capacity = capacity
        self.__slots = [None] * capacity

    @property
    def capacity(self) -> int:
        return self.__capacity

    @property
    def slots(self) -> list:
        return list(self.__slots)

    def is_empty(self) -> bool:
        return all(slot is None for slot in self.__slots)

    def put_bid(self, bid: Bid) -> int:
        # Д1033: постановка на первое свободное место от начала без сдвига остальных
        for i in range(self.__capacity):
            if self.__slots[i] is None:
                self.__slots[i] = bid
                return i
        return -1

    def select_bid(self) -> Bid | None:
        # Д2Б4: приоритет по меньшему номеру источника; при равенстве — последняя поступившая
        best_idx = -1
        best_bid = None
        for i in range(self.__capacity):
            bid = self.__slots[i]
            if bid is not None:
                if best_bid is None:
                    best_bid = bid
                    best_idx = i
                else:
                    if bid.source_id < best_bid.source_id:
                        best_bid = bid
                        best_idx = i
                    elif bid.source_id == best_bid.source_id:
                        if (bid.arrival_time, bid.id) > (best_bid.arrival_time, best_bid.id):
                            best_bid = bid
                            best_idx = i
        if best_idx != -1:
            self.__slots[best_idx] = None
            return best_bid
        return None


class Device:
    def __init__(self, device_id: int, mean_time: float):
        self.__id = device_id
        self.__mean_time = mean_time
        self.__busy = False
        self.__current_bid = None

    @property
    def id(self) -> int:
        return self.__id

    @property
    def busy(self) -> bool:
        return self.__busy

    @property
    def current_bid(self) -> Bid | None:
        return self.__current_bid

    def is_free(self) -> bool:
        return not self.__busy

    def serve(self, bid: Bid, current_time: float) -> float:
        # ПЗ1: экспоненциальное время обслуживания
        self.__busy = True
        self.__current_bid = bid
        service_time = random.expovariate(1.0 / self.__mean_time)
        return current_time + service_time

    def release(self) -> Bid | None:
        finished_bid = self.__current_bid
        self.__busy = False
        self.__current_bid = None
        return finished_bid


class DispatcherPut:
    """Диспетчер постановки: работает только с буфером (Д1033, Д10О5)."""
    def __init__(self, buffer: Buffer):
        self.__buffer = buffer

    def place_bid(self, bid: Bid) -> int:
        return self.__buffer.put_bid(bid)


class DispatcherSelect:
    """Диспетчер выбора: выбирает заявку из буфера (Д2Б4) и свободный прибор (Д2П1)."""
    def __init__(self, buffer: Buffer, devices: list[Device]):
        self.__buffer = buffer
        self.__devices = devices

    def select_device(self) -> Device | None:
        # Д2П1: последовательный перебор начиная с самого приоритетного (Д1, Д2...)
        for dev in self.__devices:
            if dev.is_free():
                return dev
        return None

    def dispatch(self, current_time: float) -> tuple[Bid, Device, float] | None:
        if self.__buffer.is_empty():
            return None
        free_dev = self.select_device()
        if free_dev is None:
            return None
        bid = self.__buffer.select_bid()
        end_time = free_dev.serve(bid, current_time)
        return bid, free_dev, end_time


def print_step_state(sources, buffer, devices, event_queue, total_gen, total_ref):
    ref_rate = (total_ref / total_gen * 100) if total_gen > 0 else 0.0

    print("\n--- СОСТОЯНИЕ СИСТЕМЫ ---")
    print("Диспетчеры (Приборы):")
    for d in devices:
        status = f"ЗАНЯТ -> обрабатывает {d.current_bid}" if d.busy else "свободен"
        print(f"  • Диспетчер {d.id}: {status}")

    print("Очередь (Буфер, без сдвига):")
    for i, slot in enumerate(buffer.slots):
        if slot:
            print(f"  • Место {i + 1}: {slot} (ждёт с t={slot.arrival_time:.2f})")
        else:
            print(f"  • Место {i + 1}: [ пусто ]")

    print("Клиенты (Источники):")
    for s in sources:
        print(f"  • Клиент {s.id}: создал заказов — {s.generated}, отказов — {s.refused}")
    print(f"Итого: создано = {total_gen} | отказов = {total_ref} ({ref_rate:.1f}%)")

    print("Календарь будущих событий:")
    print(f"  {'Время':<8} | {'Что произойдёт'}")
    print(f"  {'-' * 8}-+-{'-' * 45}")
    for ev_time, _, ev_type, ev_obj in sorted(event_queue, key=lambda x: (x[0], x[1])):
        if ev_type == "NEW_BID":
            desc = f"Новый заказ от Клиента {ev_obj.id}"
        else:
            desc = f"Диспетчер {ev_obj.id} закончит {ev_obj.current_bid}"
        print(f"  {ev_time:<8.2f} | {desc}")


def run_step_mode(num_sources=3, buffer_size=2, num_devices=2, total_events=15):
    print("=" * 65)
    print("ПОШАГОВЫЙ РЕЖИМ (ОД1) — СЛУЖБА ДОСТАВКИ ЕДЫ (ВАРИАНТ 13)")
    print("=" * 65)

    sources = [Source(i + 1, 1.0, 5.0) for i in range(num_sources)]
    buffer = Buffer(buffer_size)
    devices = [Device(i + 1, 4.0) for i in range(num_devices)]

    disp_put = DispatcherPut(buffer)
    disp_select = DispatcherSelect(buffer, devices)

    event_queue = []
    seq = 0
    bid_counter = 1
    total_gen = 0
    total_ref = 0

    for src in sources:
        seq += 1
        heapq.heappush(event_queue, (src.get_next_time(0.0), seq, "NEW_BID", src))

    step = 1
    while event_queue and step <= total_events:
        current_time, _, event_type, data = heapq.heappop(event_queue)

        print(f"\n{'=' * 65}")
        print(f"ШАГ {step}  |  Время: {current_time:.2f}")
        print(f"{'=' * 65}")

        if event_type == "NEW_BID":
            src = data
            bid = Bid(bid_counter, src.id, current_time)
            bid_counter += 1
            src.generated += 1
            total_gen += 1

            print(f"СОБЫТИЕ: Пришёл {bid}.")

            # Планируем следующий заказ от этого клиента
            seq += 1
            heapq.heappush(event_queue, (src.get_next_time(current_time), seq, "NEW_BID", src))

            # 1. Диспетчер постановки ставит заказ в буфер (Д1033)
            slot_idx = disp_put.place_bid(bid)
            if slot_idx != -1:
                print(f"  => Диспетчер постановки (Д1033): заказ помещён в буфер на Место {slot_idx + 1}.")
                # 2. Триггер для диспетчера выбора (Д2Б4 + Д2П1)
                dispatched = disp_select.dispatch(current_time)
                if dispatched:
                    served_bid, dev, end_time = dispatched
                    seq += 1
                    heapq.heappush(event_queue, (end_time, seq, "END_SERVICE", dev))
                    print(f"  => Диспетчер выбора (Д2Б4/Д2П1): {served_bid} сразу передан Диспетчеру {dev.id} (до t={end_time:.2f}).")
                else:
                    print("  => Диспетчер выбора: все диспетчеры заняты, заказ ждёт в буфере.")
            else:
                src.refused += 1
                total_ref += 1
                print(f"  => ОТКАЗ (Д10О5): буфер заполнен, {bid} удалён.")

        elif event_type == "END_SERVICE":
            dev = data
            finished_bid = dev.release()
            print(f"СОБЫТИЕ: Диспетчер {dev.id} завершил {finished_bid} и освободился.")

            # Триггер для диспетчера выбора после освобождения прибора
            dispatched = disp_select.dispatch(current_time)
            if dispatched:
                served_bid, assigned_dev, end_time = dispatched
                seq += 1
                heapq.heappush(event_queue, (end_time, seq, "END_SERVICE", assigned_dev))
                print(f"  => Диспетчер выбора (Д2Б4/Д2П1): из буфера выбран {served_bid} -> Диспетчеру {assigned_dev.id} (до t={end_time:.2f}).")
            else:
                print(f"  => Диспетчер выбора: буфер пуст, Диспетчер {dev.id} свободен.")

        print_step_state(sources, buffer, devices, event_queue, total_gen, total_ref)
        step += 1

    print("\n" + "=" * 65)
    print("Пошаговое моделирование (ОД1) завершено.")


if __name__ == "__main__":
    run_step_mode(num_sources=3, buffer_size=2, num_devices=2, total_events=15)
