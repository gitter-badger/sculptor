/*
 * Copyright 2007 The Fornax Project Team, including the original
 * author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.sculptor.generator.template.service

import org.sculptor.generator.util.OutputSlot
import org.sculptor.generator.template.common.ExceptionTmpl
import org.sculptor.generator.template.mongodb.MongoDbServiceTestTmpl
import sculptormetamodel.Parameter
import sculptormetamodel.Service
import sculptormetamodel.ServiceOperation

import static org.sculptor.generator.ext.Properties.*
import static org.sculptor.generator.template.service.ServiceTmpl.*

import static extension org.sculptor.generator.ext.Helper.*
import static extension org.sculptor.generator.util.HelperBase.*
import org.sculptor.generator.template.common.PubSubTmpl

class ServiceTmpl {

def static String service(Service it) {
	'''
	�serviceInterface(it)�
	
	�IF pureEjb3()�
		�ServiceEjbTmpl::service(it)�
	�ELSE�
		�serviceImplBase(it)�
		�IF gapClass�
			�serviceImplSubclass(it)�
		�ENDIF�
	�ENDIF�

	�IF webService�
		�ServiceEjbTmpl::webServiceInterface(it)�
		�ServiceEjbTmpl::webServicePackageInfo(it)�
	�ENDIF�

	�IF isTestToBeGenerated()�
		�ServiceTestTmpl::serviceJUnitBase(it)�
		�IF pureEjb3()�
			�ServiceEjbTestTmpl::serviceJUnitSubclassOpenEjb(it)�
		�ELSEIF applicationServer() == "appengine"�
			�ServiceTestTmpl::serviceJUnitSubclassAppEngine(it)�
		�ELSEIF mongoDb()�
			�MongoDbServiceTestTmpl::serviceJUnitSubclassMongoDb(it)�
		�ELSE�
			�ServiceTestTmpl::serviceJUnitSubclassWithAnnotations(it)�
		�ENDIF�
		�IF isDbUnitTestDataToBeGenerated()�
			�ServiceTestTmpl::dbunitTestData(it)�
		�ENDIF�
		�IF !otherDependencies.isEmpty�
			�ServiceTestTmpl::serviceDependencyInjectionJUnit(it)�
		�ENDIF�
	�ENDIF�
	'''
}

def static String serviceInterface(Service it) {
	fileOutput(javaFileName(it.getServiceapiPackage() + "." + name), OutputSlot::TO_GEN_SRC, '''
	�javaHeader()�
	package �it.getServiceapiPackage()�;

	�IF it.formatJavaDoc() == "" �
	/**
	 * Generated interface for the Service �name�.
	 */
	�ELSE �
		�it.formatJavaDoc()�
	�ENDIF �
	public interface �name� �IF subscribe != null� extends �fw("event.EventSubscriber")� �ENDIF�{

	�IF isSpringToBeGenerated()�
		public final static String BEAN_ID = "�name.toFirstLower()�";
		�ENDIF�

		�it.operations.filter(op | op.isPublicVisibility()).map[interfaceMethod(it)].join�
		
		�serviceInterfaceHook(it)�

	}
	'''
	)
	'''
	'''
}

def static String interfaceMethod(ServiceOperation it) {
	'''
		�it.formatJavaDoc()�
		public �it.getTypeName()� �name�(�it.parameters.map[e | anotParamTypeAndName(e)].join(",")�) �ExceptionTmpl::throwsDecl(it)�;
	'''
}



def static String serviceImplBase(Service it) {
	fileOutput(javaFileName(it.getServiceimplPackage() + "." + name + "Impl" + (if (gapClass) "Base" else "")), OutputSlot::TO_GEN_SRC, '''
	�javaHeader()�
	package �it.getServiceimplPackage()�;

	�IF gapClass�
	/**
	 * Generated base class for implementation of �name�.
	�IF isSpringToBeGenerated()�
		 * <p>Make sure that subclass defines the following annotations:
		 * <pre>
		�springServiceAnnotation(it)�
		 * </pre>
		 *
	�ENDIF�
	 */
	�ELSE�
		 /**
		 * Implementation of �name�.
		 */
		�IF isSpringToBeGenerated()�
			�springServiceAnnotation(it)�
		�ENDIF�
		�IF !gapClass && webService�
			�ServiceEjbTmpl::webServiceAnnotations(it)�
		�ENDIF�
	�ENDIF�
	�IF subscribe != null��PubSubTmpl::subscribeAnnotation(it.subscribe)��ENDIF�
	public �IF gapClass�abstract �ENDIF�class �name�Impl�IF gapClass�Base�ENDIF� �it.extendsLitteral()� implements �it.getServiceapiPackage()�.�name� {

		public �name�Impl�IF gapClass�Base�ENDIF�() {
		}

		�delegateRepositories(it) �
		�delegateServices(it) �

		�it.operations.filter(op | !op.isImplementedInGapClass()).map[implMethod(it)].join�
		
		�serviceHook(it)�
	}
	'''
	)
}

def static String springServiceAnnotation(Service it) {
	'''
	@org.springframework.stereotype.Service("�name.toFirstLower()�")
	'''
}

def static String delegateRepositories(Service it) {
	'''
	�FOR delegateRepository  : it.getDelegateRepositories()�
		�IF isSpringToBeGenerated()�
			@org.springframework.beans.factory.annotation.Autowired
		�ENDIF�
		�IF pureEjb3()�
			@javax.ejb.EJB
		�ENDIF�
			private �getRepositoryapiPackage(delegateRepository.aggregateRoot.module)�.�delegateRepository.name� �delegateRepository.name.toFirstLower()�;

			protected �getRepositoryapiPackage(delegateRepository.aggregateRoot.module)�.�delegateRepository.name� get�delegateRepository.name�() {
				return �delegateRepository.name.toFirstLower()�;
			}
		�ENDFOR�
	'''
}

def static String delegateServices(Service it) {
	'''
	�FOR delegateService  : it.getDelegateServices()�
		�IF isSpringToBeGenerated()�
			@org.springframework.beans.factory.annotation.Autowired
		�ENDIF�
		�IF pureEjb3()�
			@javax.ejb.EJB
		�ENDIF�
			private �getServiceapiPackage(delegateService)�.�delegateService.name��IF pureEjb3()�Local�ENDIF� �delegateService.name.toFirstLower()�;

			protected �getServiceapiPackage(delegateService)�.�delegateService.name� get�delegateService.name�() {
				return �delegateService.name.toFirstLower()�;
			}
		�ENDFOR�
	'''
}

def static String serviceImplSubclass(Service it) {
	fileOutput(javaFileName(it.getServiceimplPackage() + "." + name + "Impl"), OutputSlot::TO_SRC, '''
	�javaHeader()�
	package �it.getServiceimplPackage()�;

	/**
	 * Implementation of �name�.
	 */
	�IF isSpringToBeGenerated()�
		@org.springframework.stereotype.Service("�name.toFirstLower()�")
	�ENDIF�
	�IF webService�
		�ServiceEjbTmpl::webServiceAnnotations(it)�
	�ENDIF�
	public class �name�Impl ^extends �name�ImplBase {

		public �name�Impl() {
		}

	�otherDependencies(it)�

		�it.operations.filter(op | op.isImplementedInGapClass()) .map[implMethod(it)].join()�

	}
	'''
	)
}

def static String otherDependencies(Service it) {
	'''
	�FOR dependency  : otherDependencies�
		/**
		 * Dependency injection
		 */
		�IF isSpringToBeGenerated()�
			@org.springframework.beans.factory.annotation.Autowired
		�ENDIF�
		�IF pureEjb3()�
			@javax.ejb.EJB
		�ENDIF�
		public void set�dependency.toFirstUpper()�(Object �dependency�) {
			// TODO implement setter for dependency injection of �dependency�
			throw new UnsupportedOperationException("Implement setter for dependency injection of �dependency� in �name�Impl");
		}

	�ENDFOR�
	'''
}

def static String implMethod(ServiceOperation it) {
	'''
	�IF delegate != null �
		/**
		 * Delegates to {@link �getRepositoryapiPackage(delegate.repository.aggregateRoot.module)�.�delegate.repository.name�#�delegate.name�}
		 */
	�ELSEIF serviceDelegate != null �
		/**
		 * Delegates to {@link �getServiceapiPackage(serviceDelegate.service)�.�serviceDelegate.service.name�#�serviceDelegate.name�}
		 */
	�ENDIF �
	�serviceMethodAnnotation(it)�
	�it.getVisibilityLitteral()� �it.getTypeName()� �name�(�it.parameters.map[p | paramTypeAndName(p)].join(",")�) �ExceptionTmpl::throwsDecl(it)� {
	�IF delegate != null �
		�IF it.delegate.getTypeName() == "void" && it.getTypeName() != "void"�
			/*This is a special case which is used for save operations, when rcp nature */
			�it.delegate.repository.name.toFirstLower()�.�delegate.name�(�FOR parameter : parameters.filter(p | p.type != serviceContextClass()) SEPARATOR ", "��parameter.name��ENDFOR�);
			return �parameters.get(if (isServiceContextToBeGenerated()) 1 else 0).name�;
		�ELSE�
			�IF it.getTypeName() != "void" �return �ENDIF�
				�delegate.repository.name.toFirstLower()�.�delegate.name�(�FOR parameter  : parameters.filter(p | p.type != serviceContextClass()) SEPARATOR ", "��parameter.name��ENDFOR�);
		�ENDIF�
	�ELSEIF serviceDelegate != null �
			�IF serviceDelegate.getTypeName() != "void" && it.getTypeName() != "void" �return �ENDIF�
				�it.serviceDelegate.service.name.toFirstLower()�.�it.serviceDelegate.name�(�FOR parameter : parameters SEPARATOR ", "��parameter.name��ENDFOR�);
	�ELSE�
		// TODO Auto-generated method stub
		throw new UnsupportedOperationException("�name� not implemented");
	�ENDIF�
		}
	'''
}

def static String serviceMethodAnnotation(ServiceOperation it) {
	'''
	/*spring transaction support */
	�IF isSpringAnnotationTxToBeGenerated()�
		�IF name.startsWith("get") || name.startsWith("find")�
			@org.springframework.transaction.annotation.Transactional(readOnly=true)
		�ELSE�
			@org.springframework.transaction.annotation.Transactional(readOnly=false, rollbackFor=org.sculptor.framework.errorhandling.ApplicationException.class)
		�ENDIF�
	�ENDIF�
	�IF pureEjb3() && jpa() && !name.startsWith("get") && !name.startsWith("find")�
		@javax.interceptor.Interceptors({�service.module.getJpaFlushEagerInterceptorClass()�.class})
	�ENDIF�
	�IF service.webService�
		@javax.jws.WebMethod
	�ENDIF�
	�IF publish != null��PubSubTmpl::publishAnnotation(it.publish)��ENDIF�
	'''
}

def static String paramTypeAndName(Parameter it) {
	'''
	�it.getTypeName()� �name�
	'''
}

def static String anotParamTypeAndName(Parameter it) {
	'''
	�IF isGenerateParameterName()� @�fw("annotation.Name")�("�name�")�ENDIF� �it.getTypeName()� �name�
	'''
}

def static String serialVersionUID(Service it) {
	'''
		private static final long serialVersionUID = 1L;
	'''
}


/*Extension point to generate more stuff in service interface.
	User AROUND ServiceTmpl::serviceInterfaceHook FOR Service
	in SpecialCases.xpt */
def static String serviceInterfaceHook(Service it) {
	'''
	'''
}

/*Extension point to generate more stuff in service implementation.
	User AROUND ServiceTmpl::serviceHook FOR Service
	in SpecialCases.xpt */
def static String serviceHook(Service it) {
	'''
	'''
}
}