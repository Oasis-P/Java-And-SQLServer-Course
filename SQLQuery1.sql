create database MachineRoom --创建机房数据库

use MachineRoom
go
create table room--机房表
(rno char(3) primary key,--机房号
rnum int not null)--机房机位数
go 
create table fee --机型费率表
(ftype varchar(2) primary key,check(ftype in('Ⅰ','Ⅱ','Ⅲ')),--下拉列表选择/机器类型
ffee float not null)
go
create table machine--机器信息表
(mno char(3) check(mno like'[0-9][0-9][0-9]'),--check约束为三位数字/机器号
mtype varchar(2) foreign key references fee(ftype),--机器类型
mrno char(3) foreign key references room(rno),--外键约束 /机房号
primary key(mno,mrno))
go
create table admini-- 管理员信息表
(ano char(6) primary key,--管理员工号
aname varchar(20) not null)--管理员姓名
go
create table student--学生信息表
(sno char(12) primary key,--学号
sname varchar(20) not null,--姓名
sclass varchar(10) not null,--班级
--scollege varchar(50) not null,--学院
)
go
create table cardinfo--上机证信息表
(--cardsno char(12) foreign key references student(sno) on delete cascade,--学号
cardno varchar(12) primary key,--上机证号
cardpw varchar(18) not null,--密码
cardbalance float not null)--余额
go
create table einfo--登录信息表
(ecardno varchar(12) not null foreign key references cardinfo(cardno) on delete cascade,--上机证号
emno char(3) not null,--登录机器号
ebegtime datetime ,--上机时间
eendtime datetime ,--下机时间
eaddress char(3) not null,--上机地
bencifee float,--本次消费
primary key(ecardno,ebegtime))
go
create table czinfo--充值信息表
(czsno char(12)foreign key references student(sno),--学号
czcardno varchar(12) foreign key references cardinfo(cardno)on delete cascade,--上机证号
cztime Datetime,--充值时间
cznum float,--充值数
)
alter table czinfo
add constraint pk_cz primary key(czsno,cztime)
/*创建触发器增加新上机用户*/
go
create trigger tri1 on czinfo
instead of insert
as
if(select cztime from inserted)is null
begin
	insert into cardinfo values((select czcardno from inserted),'000',0)--密码默认000
	insert into czinfo values ((select czsno from inserted),(select czcardno from inserted),getdate(),0)--插入充值信息表
	insert into einfo  values ((select czcardno from inserted),'000',getdate(),getdate(),'303',0)
end
else
insert into czinfo values ((select czsno from inserted),(select czcardno from inserted),getdate(),(select cznum from inserted))
/*创建触发器，删除学生信息时级联删除上机证信息*/
go 
create trigger tri2 on student
instead of delete
as
delete from cardinfo where cardno in(select czcardno from czinfo where czsno =(select sno from deleted))
delete from student where sno=(select sno from deleted)
/*创建触发器使一个学生同一时间内只能用一台机器,余额能否上机*/
go
create trigger tri3 on einfo
instead of insert
as
create table temp --创建临时表存储部分登录信息
(i int identity(1,1),
tbeg datetime,
tend datetime)
insert into temp select ebegtime,eendtime from einfo where ecardno = (select ecardno from inserted)--查插入前einfo表中的信息
if(select count(*) from temp)<>0--用户首次登录无信息
if (select cardbalance from cardinfo where cardno=(select ecardno from inserted))>0--余额不足
		if(select tend from temp where i=(select count(*)from temp))is null 
		begin 
			print'该上机证已在其他地方登录'
			--rollback
		end
		else 
		insert into einfo values((select ecardno from inserted),(select emno from inserted),GETDATE(),(select eendtime from inserted),(select eaddress from inserted),(select bencifee from inserted))
	else
	--rollback 
	print'余额不足，请充值'
else
	insert into einfo values((select ecardno from inserted),(select emno from inserted),GETDATE(),(select eendtime from inserted),(select eaddress from inserted),(select bencifee from inserted))
drop table temp --删除临时表
/*创建触发器，下机时实现扣费*/
go
create trigger tri4 on einfo
for update
as
if(select len(ecardno) from inserted)>6--判断是否为学生上机
begin
declare @i int 
set @i=datediff(hh,(select ebegtime from inserted),getdate())--计算时间间隔
print @i
--登录信息表登记本次消费
update einfo set bencifee=@i*
(select ffee from fee where ftype=                 
(select mtype from machine where mno=(select emno from inserted))) where ecardno=(select ecardno from inserted)and bencifee is null--更新本次消费
--上机证表余额扣费
update cardinfo set cardbalance=cardbalance-@i*--扣费
(select ffee from fee where ftype=                  --根据机器类型查费用
(select mtype from machine where mno=(select emno from inserted)))--根据机器号查机器类型
where cardno=(select ecardno from inserted)
end
/*创建视图，在学生成功登录后显示本次登录信息*/
go
create view  jibenxinxi 
as
select sname,czcardno,cardbalance,ebegtime,eendtime,eaddress,bencifee from student,czinfo,cardinfo,einfo
where sno=czsno and czcardno=cardno and cardno=ecardno 
group by sname,czcardno,cardbalance,ebegtime,eendtime,eaddress,bencifee
/*创建视图，管理员根据上机证号查询学生基本信息*/
go
create view studentinfo
as
select sno,sname,sclass,czcardno,cardbalance from student,czinfo,cardinfo
where sno=czsno and czcardno=cardno
group by sno,sname,sclass,czcardno,cardbalance
/*创建存储过程，充值时，添加充值时间，更新上机证表中的余额*/
go
create proc proc1 @cardno varchar(12),@num float
as
insert into czinfo values((select czsno from czinfo where czcardno=@cardno group by czsno),@cardno,getdate(),@num)
update cardinfo set cardbalance=cardbalance+@num where cardno=@cardno
/*创建存储过程，登录成功后显示本次登录信息*/
go
create proc proc2 @cardno varchar(12)
as
select sname,czcardno,ebegtime,eaddress,cardbalance from jibenxinxi where czcardno=@cardno and eendtime is null
--execute proc2 '20070219'
--drop view jibenxinxi
--drop proc proc2
/*创建存储过程，登录时在登录表中增加登录时间*/
go
create proc proc3 @cardno varchar(12),@room char(3)
as
insert into einfo(ecardno,emno,ebegtime,eaddress) values(@cardno,'018',GETDATE(),@room)
/*创建存储过程，添加管理员信息时同时增加其上机证信息*/
go
create proc proc4 @ano char(6),@aname varchar(20)
as
insert into admini values(@ano,@aname)
insert into cardinfo values(@ano,'000',0)
/*创建存储过程实现统计各机房费用*/
go
create proc proc5 
as
select eaddress,SUM(bencifee)as sum_fee from einfo 
group by eaddress
/*增加学生信息*/
go
insert into student values('201720070218','彭泽华','计科二班')
insert into student values('201720070226','叶鑫','计科二班')
insert into student values('201720070227','邓钰','计科二班')
insert into student values('201720070219','杨祥','计科二班')
insert into student values('201720070202','余昊','计科二班')
/*下机*/
update einfo set eendtime=getdate()   where ecardno='20070218' and eendtime is null
/*上机*/
--存储过程上机
execute proc3 '20070219','403'
insert into einfo(ecardno,emno,ebegtime,eaddress) values('20070218','018',GETDATE(),'303')
/*充值*/
execute proc1 '20070218',1
/*登录扣费*/
--费用表，费用标准
insert into fee values('Ⅰ',1.5)
insert into fee values('Ⅱ',1)
insert into fee values('Ⅲ',0.5)
--机房表
insert into room values('303',60)
insert into room values('403',100)
insert into room values('503',85)
--机器表
insert into machine values('000','Ⅰ','303')
insert into machine values('017','Ⅰ','303')
insert into machine values('027','Ⅰ','303')
insert into machine values('037','Ⅰ','303')
insert into machine values('018','Ⅱ','303')
insert into machine values('028','Ⅱ','303')
insert into machine values('038','Ⅱ','303')
insert into machine values('019','Ⅲ','303')
insert into machine values('029','Ⅲ','303')
insert into machine values('039','Ⅲ','303')
/*管理员登录*/
--统计各机房费用
execute proc5
select eaddress,SUM(bencifee)as sum_fee from einfo 
group by eaddress
--创建存储过程，注册管理员同时注册上机证号
execute proc4 '000000','张三'
/*增加学生上机证信息*/
insert into czinfo values('201720070219','20070219',null,null)

delete from student  where sno='201720070218'
delete from student  where sno='201720070219'
delete from student  where sno='201720070226'
delete from student  where sno='201720070202'
