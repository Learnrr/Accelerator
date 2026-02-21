import torch
from torch import nn
import torchvision.transforms
from torch.utils.tensorboard import SummaryWriter
from torch.utils import data

from model import *

# create dataset
train_dataset = torchvision.datasets.CIFAR10(root='./data', train=True, download=False,
                                             transform=torchvision.transforms.ToTensor())
test_dataset = torchvision.datasets.CIFAR10(root='./data', train=False, download=False,
                                            transform=torchvision.transforms.ToTensor())
# data size
train_size = len(train_dataset)
test_size = len(test_dataset)

# dataloader
train_loader = torch.utils.data.DataLoader(train_dataset, batch_size=64, shuffle=True)
test_loader = torch.utils.data.DataLoader(test_dataset, batch_size=64, shuffle=True)
device = 'cuda' if torch.cuda.is_available() else 'cpu'
# build up model
model = CIFAR10Model()
model = model.to(device)
# loss
loss_fn = nn.CrossEntropyLoss()

learn_rate = 0.02
optimizer = torch.optim.SGD(model.parameters(), lr=learn_rate)

# document total step
total_train_step = 0
total_test_step = 0

# epochs
epoch = 50

# TensorBoard
writer = SummaryWriter('./CIFAR10_logs')

for i in range(epoch):
    # train
    print(f"----------------------------training of {i+1} epoch----------------------------")
    model.train()
    # steps in ith epoch
    pre_train_step = 0
    # total loss in ith epoch
    pre_train_loss = 0
    for data in train_loader:
        inputs, labels = data
        outputs = model(inputs)
        optimizer.zero_grad()
        loss = loss_fn(outputs, labels)
        loss.backward()
        optimizer.step()

        pre_train_step += 1
        pre_train_loss += loss.item()
        total_train_step += 1
        # output once 100
        if pre_train_step % 100 == 0:
            print(f'training {i+1} epoch,current step:{pre_train_step},avg loss:{pre_train_loss / pre_train_step}')
            writer.add_scalar('train_loss', pre_train_loss / pre_train_step, total_train_step)
    print(f"----------------------------complete training of {i + 1} epoch----------------------------")
    # test
    model.eval()
    # total loss in ith test epoch
    pre_test_loss = 0
    # total corrects in ith epoch
    pre_accuracy = 0
    print(f"----------------------------start {i + 1} test----------------------------")
    with torch.no_grad():
        for data in test_loader:
            inputs, labels = data
            outputs = model(inputs)
            loss = loss_fn(outputs, labels)
            pre_test_loss += loss.item()
            pre_accuracy += outputs.argmax(1).eq(labels).sum().item()
    print(f'training of {i + 1}epoch,avg loss in test:{pre_test_loss / test_size},current ratio of correctness in test:{pre_accuracy / test_size}')
    writer.add_scalar('test_accuracy', pre_accuracy / test_size, i)
    print(f"----------------------------complete of {i + 1} test epoch----------------------------")
    # save model pth of every epoch
    torch.save(model.state_dict(), f'./CIFAR10TrainModel{i}.pth')
    print(f"----------------------------model saving complete of {i + 1} epoch----------------------------")

writer.close()

