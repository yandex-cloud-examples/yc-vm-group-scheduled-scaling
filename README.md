# Масштабирование группы виртуальных машин по расписанию

Разверните инфраструктуру для масштабирования группы виртуальных машин по расписанию. Вы создадите [группу ВМ](https://yandex.cloud/ru/docs/compute/concepts/instance-groups/) с помощью сервиса [Yandex Compute Cloud](https://yandex.cloud/ru/docs/compute/) и настройте для нее [масштабирование](https://yandex.cloud/ru/docs/compute/concepts/instance-groups/scale) по расписанию. Размером группы ВМ будет управлять [функция](https://yandex.cloud/ru/docs/functions/concepts/function) [Yandex Cloud Functions](https://yandex.cloud/ru/docs/functions/), запускаемая по [таймеру](https://yandex.cloud/ru/docs/functions/concepts/trigger/timer).

Подготовка инфраструктуры для масштабирования группы виртуальных машин по расписанию с помощью Terraform описана в [практическом руководстве](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/vm-scale-scheduled/), необходимые для настройки конфигурационные файлы 
`vm-scale-scheduled.tf` и `vm-scale-scheduled-function.zip` расположены в этом репозитории.
