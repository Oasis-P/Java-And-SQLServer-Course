create database MachineRoom --�����������ݿ�

use MachineRoom
go
create table room--������
(rno char(3) primary key,--������
rnum int not null)--������λ��
go 
create table fee --���ͷ��ʱ�
(ftype varchar(2) primary key,check(ftype in('��','��','��')),--�����б�ѡ��/��������
ffee float not null)
go
create table machine--������Ϣ��
(mno char(3) check(mno like'[0-9][0-9][0-9]'),--checkԼ��Ϊ��λ����/������
mtype varchar(2) foreign key references fee(ftype),--��������
mrno char(3) foreign key references room(rno),--���Լ�� /������
primary key(mno,mrno))
go
create table admini-- ����Ա��Ϣ��
(ano char(6) primary key,--����Ա����
aname varchar(20) not null)--����Ա����
go
create table student--ѧ����Ϣ��
(sno char(12) primary key,--ѧ��
sname varchar(20) not null,--����
sclass varchar(10) not null,--�༶
--scollege varchar(50) not null,--ѧԺ
)
go
create table cardinfo--�ϻ�֤��Ϣ��
(--cardsno char(12) foreign key references student(sno) on delete cascade,--ѧ��
cardno varchar(12) primary key,--�ϻ�֤��
cardpw varchar(18) not null,--����
cardbalance float not null)--���
go
create table einfo--��¼��Ϣ��
(ecardno varchar(12) not null foreign key references cardinfo(cardno) on delete cascade,--�ϻ�֤��
emno char(3) not null,--��¼������
ebegtime datetime ,--�ϻ�ʱ��
eendtime datetime ,--�»�ʱ��
eaddress char(3) not null,--�ϻ���
bencifee float,--��������
primary key(ecardno,ebegtime))
go
create table czinfo--��ֵ��Ϣ��
(czsno char(12)foreign key references student(sno),--ѧ��
czcardno varchar(12) foreign key references cardinfo(cardno)on delete cascade,--�ϻ�֤��
cztime Datetime,--��ֵʱ��
cznum float,--��ֵ��
)
alter table czinfo
add constraint pk_cz primary key(czsno,cztime)
/*�����������������ϻ��û�*/
go
create trigger tri1 on czinfo
instead of insert
as
if(select cztime from inserted)is null
begin
	insert into cardinfo values((select czcardno from inserted),'000',0)--����Ĭ��000
	insert into czinfo values ((select czsno from inserted),(select czcardno from inserted),getdate(),0)--�����ֵ��Ϣ��
	insert into einfo  values ((select czcardno from inserted),'000',getdate(),getdate(),'303',0)
end
else
insert into czinfo values ((select czsno from inserted),(select czcardno from inserted),getdate(),(select cznum from inserted))
/*������������ɾ��ѧ����Ϣʱ����ɾ���ϻ�֤��Ϣ*/
go 
create trigger tri2 on student
instead of delete
as
delete from cardinfo where cardno in(select czcardno from czinfo where czsno =(select sno from deleted))
delete from student where sno=(select sno from deleted)
/*����������ʹһ��ѧ��ͬһʱ����ֻ����һ̨����,����ܷ��ϻ�*/
go
create trigger tri3 on einfo
instead of insert
as
create table temp --������ʱ��洢���ֵ�¼��Ϣ
(i int identity(1,1),
tbeg datetime,
tend datetime)
insert into temp select ebegtime,eendtime from einfo where ecardno = (select ecardno from inserted)--�����ǰeinfo���е���Ϣ
if(select count(*) from temp)<>0--�û��״ε�¼����Ϣ
if (select cardbalance from cardinfo where cardno=(select ecardno from inserted))>0--����
		if(select tend from temp where i=(select count(*)from temp))is null 
		begin 
			print'���ϻ�֤���������ط���¼'
			--rollback
		end
		else 
		insert into einfo values((select ecardno from inserted),(select emno from inserted),GETDATE(),(select eendtime from inserted),(select eaddress from inserted),(select bencifee from inserted))
	else
	--rollback 
	print'���㣬���ֵ'
else
	insert into einfo values((select ecardno from inserted),(select emno from inserted),GETDATE(),(select eendtime from inserted),(select eaddress from inserted),(select bencifee from inserted))
drop table temp --ɾ����ʱ��
/*�������������»�ʱʵ�ֿ۷�*/
go
create trigger tri4 on einfo
for update
as
if(select len(ecardno) from inserted)>6--�ж��Ƿ�Ϊѧ���ϻ�
begin
declare @i int 
set @i=datediff(hh,(select ebegtime from inserted),getdate())--����ʱ����
print @i
--��¼��Ϣ��ǼǱ�������
update einfo set bencifee=@i*
(select ffee from fee where ftype=                 
(select mtype from machine where mno=(select emno from inserted))) where ecardno=(select ecardno from inserted)and bencifee is null--���±�������
--�ϻ�֤�����۷�
update cardinfo set cardbalance=cardbalance-@i*--�۷�
(select ffee from fee where ftype=                  --���ݻ������Ͳ����
(select mtype from machine where mno=(select emno from inserted)))--���ݻ����Ų��������
where cardno=(select ecardno from inserted)
end
/*������ͼ����ѧ���ɹ���¼����ʾ���ε�¼��Ϣ*/
go
create view  jibenxinxi 
as
select sname,czcardno,cardbalance,ebegtime,eendtime,eaddress,bencifee from student,czinfo,cardinfo,einfo
where sno=czsno and czcardno=cardno and cardno=ecardno 
group by sname,czcardno,cardbalance,ebegtime,eendtime,eaddress,bencifee
/*������ͼ������Ա�����ϻ�֤�Ų�ѯѧ��������Ϣ*/
go
create view studentinfo
as
select sno,sname,sclass,czcardno,cardbalance from student,czinfo,cardinfo
where sno=czsno and czcardno=cardno
group by sno,sname,sclass,czcardno,cardbalance
/*�����洢���̣���ֵʱ����ӳ�ֵʱ�䣬�����ϻ�֤���е����*/
go
create proc proc1 @cardno varchar(12),@num float
as
insert into czinfo values((select czsno from czinfo where czcardno=@cardno group by czsno),@cardno,getdate(),@num)
update cardinfo set cardbalance=cardbalance+@num where cardno=@cardno
/*�����洢���̣���¼�ɹ�����ʾ���ε�¼��Ϣ*/
go
create proc proc2 @cardno varchar(12)
as
select sname,czcardno,ebegtime,eaddress,cardbalance from jibenxinxi where czcardno=@cardno and eendtime is null
--execute proc2 '20070219'
--drop view jibenxinxi
--drop proc proc2
/*�����洢���̣���¼ʱ�ڵ�¼�������ӵ�¼ʱ��*/
go
create proc proc3 @cardno varchar(12),@room char(3)
as
insert into einfo(ecardno,emno,ebegtime,eaddress) values(@cardno,'018',GETDATE(),@room)
/*�����洢���̣���ӹ���Ա��Ϣʱͬʱ�������ϻ�֤��Ϣ*/
go
create proc proc4 @ano char(6),@aname varchar(20)
as
insert into admini values(@ano,@aname)
insert into cardinfo values(@ano,'000',0)
/*�����洢����ʵ��ͳ�Ƹ���������*/
go
create proc proc5 
as
select eaddress,SUM(bencifee)as sum_fee from einfo 
group by eaddress
/*����ѧ����Ϣ*/
go
insert into student values('201720070218','����','�ƿƶ���')
insert into student values('201720070226','Ҷ��','�ƿƶ���')
insert into student values('201720070227','����','�ƿƶ���')
insert into student values('201720070219','����','�ƿƶ���')
insert into student values('201720070202','���','�ƿƶ���')
/*�»�*/
update einfo set eendtime=getdate()   where ecardno='20070218' and eendtime is null
/*�ϻ�*/
--�洢�����ϻ�
execute proc3 '20070219','403'
insert into einfo(ecardno,emno,ebegtime,eaddress) values('20070218','018',GETDATE(),'303')
/*��ֵ*/
execute proc1 '20070218',1
/*��¼�۷�*/
--���ñ����ñ�׼
insert into fee values('��',1.5)
insert into fee values('��',1)
insert into fee values('��',0.5)
--������
insert into room values('303',60)
insert into room values('403',100)
insert into room values('503',85)
--������
insert into machine values('000','��','303')
insert into machine values('017','��','303')
insert into machine values('027','��','303')
insert into machine values('037','��','303')
insert into machine values('018','��','303')
insert into machine values('028','��','303')
insert into machine values('038','��','303')
insert into machine values('019','��','303')
insert into machine values('029','��','303')
insert into machine values('039','��','303')
/*����Ա��¼*/
--ͳ�Ƹ���������
execute proc5
select eaddress,SUM(bencifee)as sum_fee from einfo 
group by eaddress
--�����洢���̣�ע�����Աͬʱע���ϻ�֤��
execute proc4 '000000','����'
/*����ѧ���ϻ�֤��Ϣ*/
insert into czinfo values('201720070219','20070219',null,null)

delete from student  where sno='201720070218'
delete from student  where sno='201720070219'
delete from student  where sno='201720070226'
delete from student  where sno='201720070202'
